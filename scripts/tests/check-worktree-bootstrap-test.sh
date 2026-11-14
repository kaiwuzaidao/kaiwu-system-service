#!/usr/bin/env sh
set -eu

repo_dir="$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
workspace="$fixture/workspace"
mkdir -p "$workspace" "$fixture/bin"

# Use real Git checkouts and linked worktrees; mock only build/runtime tools.
for repository in kaiwu-system-service kaiwu-system-starter kaiwu-gateway-service kaiwu-system-web; do
  source_repo="$fixture/$repository"
  git init -q "$source_repo"
  git -C "$source_repo" -c user.name=Test -c user.email=test@example.invalid \
    commit -q --allow-empty -m fixture
  if [ "$repository" = kaiwu-system-web ]; then
    git clone -q "$source_repo" "$workspace/$repository"
  else
    git -C "$source_repo" worktree add -q --detach "$workspace/$repository" HEAD
    test -f "$workspace/$repository/.git"
  fi
done
system_repo="$workspace/kaiwu-system-service"
helper_dir="$system_repo/.agents/skills/kaiwu-development/scripts"
mkdir -p "$system_repo/scripts" "$helper_dir"
cp "$repo_dir/scripts/kaiwu.sh" "$repo_dir/scripts/database-config.sh" "$system_repo/scripts/"
export KAIWU_DB_TYPE=mysql
cp "$repo_dir/kaiwu-workspace.env" "$system_repo/"
cp "$repo_dir/.agents/skills/kaiwu-development/scripts/kaiwu-agent.sh" "$helper_dir/"
cat > "$fixture/bin/docker" <<'MOCK'
#!/usr/bin/env sh
if [ "${1:-}" = info ] && [ "${2:-}" = --format ]; then
  printf '8589934592\n'
fi
MOCK
cat > "$fixture/bin/java" <<'MOCK'
#!/usr/bin/env sh
printf 'openjdk version "21.0.5"\n' >&2
MOCK
cat > "$fixture/bin/mvn" <<'MOCK'
#!/usr/bin/env sh
printf '%s\n' "$PWD" >> "$KAIWU_TEST_BUILD_LOG"
MOCK
cat > "$fixture/bin/corepack" <<'MOCK'
#!/usr/bin/env sh
printf '%s\n' "$PWD" >> "$KAIWU_TEST_BUILD_LOG"
MOCK
cat > "$fixture/bin/openssl" <<'MOCK'
#!/usr/bin/env sh
printf 'fixture-only-placeholder\n'
MOCK
cat > "$fixture/bin/curl" <<'MOCK'
#!/usr/bin/env sh
exit 0
MOCK
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
git -C "$system_repo" add .
git -C "$system_repo" -c user.name=Test -c user.email=test@example.invalid \
  commit -q -m 'bootstrap fixture'
export KAIWU_TEST_BUILD_LOG="$fixture/build.log"

bash "$system_repo/scripts/kaiwu.sh" doctor > "$fixture/doctor.log"
bash "$helper_dir/kaiwu-agent.sh" doctor > "$fixture/agent-doctor.log"
for repository in kaiwu-system-service kaiwu-system-starter kaiwu-gateway-service kaiwu-system-web; do
  grep -Eq "^ok +$repository +branch=" "$fixture/agent-doctor.log"
done
# Initialization must reuse all existing checkouts, preserving dirty files and HEAD.
printf 'keep local changes\n' > "$workspace/kaiwu-system-starter/local-change.txt"
head_before="$(git -C "$workspace/kaiwu-system-starter" rev-parse HEAD)"
bash "$system_repo/scripts/kaiwu.sh" init > "$fixture/init.log"
test "$(git -C "$workspace/kaiwu-system-starter" rev-parse HEAD)" = "$head_before"
grep -Fq 'keep local changes' "$workspace/kaiwu-system-starter/local-change.txt"
for repository in kaiwu-system-service kaiwu-system-starter kaiwu-gateway-service kaiwu-system-web; do
  grep -Fq "$repository=$(git -C "$workspace/$repository" rev-parse HEAD)" \
    "$workspace/.kaiwu/workspace.lock"
done
bash "$helper_dir/kaiwu-agent.sh" verify auto > "$fixture/verify.log"
grep -Fxq "$workspace/kaiwu-system-starter" "$KAIWU_TEST_BUILD_LOG"

# An ordinary child directory inside another Git checkout must still be refused.
# A forged .git file must not turn that directory into an accepted checkout.
git init -q "$workspace"
mv "$workspace/kaiwu-system-web" "$fixture/saved-web"
mkdir "$workspace/kaiwu-system-web"
printf 'preserve me\n' > "$workspace/kaiwu-system-web/user-file.txt"
for state in ordinary forged; do
  if [ "$state" = forged ]; then
    printf 'gitdir: /nonexistent-kaiwu-fixture\n' > "$workspace/kaiwu-system-web/.git"
  fi
  if bash "$system_repo/scripts/kaiwu.sh" init > "$fixture/rejected.log" 2>&1; then
    echo "Initializer accepted $state non-Git directory" >&2
    exit 1
  fi
  grep -Fq 'preserve me' "$workspace/kaiwu-system-web/user-file.txt"
done
printf 'Git worktree bootstrap checks passed.\n'
