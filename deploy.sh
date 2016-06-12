# Temporarily store uncommited changes
git stash

# Verify correct branch
git checkout master

# Build new files
stack exec blog clean
stack exec blog build

# Get previous files
git fetch -all
git checkout -b gh-pages --track origin/gh-pages

# Overwrite existing files with new files
cp -a _site/. .

# Commit
git add -A
git commit -m "Publish."

# Push
git push origin gh-pages:gh-pages

# Restoration
git checkout master
git branch -D gh-pages
git stash pop
