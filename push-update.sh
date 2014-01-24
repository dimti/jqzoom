#!/bin/bash
PATH_LIB='/js/jqzoom'
PROJECTS=( "/var/www/predelanet" "/var/www/zelenoemore" )
if [ ! -f "CHANGELOG.md" ]
then
    echo "CHANGELOG.md not exists\n"
    exit 1
fi
test -n "`tail CHANGELOG.md`"
CHANGELOG_EMPTY=`echo $?`
if [ $CHANGELOG_EMPTY == 1 ]
then
    echo -e "CHANGELOG.md is empty\n"
    exit 1
fi
git diff-index --quiet HEAD --
REPO_CHANGED=`echo $?`
if [ $REPO_CHANGED == 1 ]
then
    echo -e "Please commit all changes in repository\n"
    exit 1
fi
VERSION_PREVIOUS=`sed -n '4,4p' CHANGELOG.md | cut -d "(" -f1 | tr -d ' '`
if [ `git rev-parse ${VERSION_PREVIOUS}` != `git rev-parse HEAD` ]
then
    VERSION=`echo ${VERSION_PREVIOUS} | awk -F. -v OFS=. 'NF==1{print ++$NF}; NF>1{if(length($NF+1)>length($NF))$(NF-1)++; $NF=sprintf("%0*d", length($NF), ($NF+1)%(10^length($NF))); print}'`
    git tag "$VERSION" &&
    gitchangelog > CHANGELOG.md &&
    {
        git add CHANGELOG.md >/dev/null &&
        git commit -m "Update CHANGELOG.md" > /dev/null &&
        git tag -d "$VERSION" >/dev/null &&
        git tag "$VERSION" >/dev/null &&
        git push --tags >/dev/null 2>/dev/null
    } || {
        echo -e "Cannot push released tag into remote repository\n"
        exit 1
    }
else
    VERSION=$VERSION_PREVIOUS
fi
git push >/dev/null || exit 1

MESSAGE="\nUpdate ${PATH_LIB} on ${VERSION}\n"
CURRENT_DIR=`pwd`
for project in "${PROJECTS[@]}"
do
	echo -e "Update lib for ${project}...\n"
	{
        cd "${project}${PATH_LIB}" &&
        git fetch >/dev/null 2>/dev/null &&
        git checkout "$VERSION" 2>/dev/null;
	} || {
	    echo -e "Failed to checkout lib on tag ${VERSION}\n" &&
	    exit 1;
    }
	cd "${project}"
	LIB_DIR=`echo ${PATH_LIB#'/'}`
	git diff-index --quiet HEAD "$LIB_DIR"
	LIB_NEW_COMMITS=`echo $?`
	if [ $LIB_NEW_COMMITS == 1 ]
	then
	    {
	        git reset >/dev/null &&
            git add "$LIB_DIR" >/dev/null &&
            git commit -m "$MESSAGE" >/dev/null
        } || {
            echo -e "Failed to update lib for ${project}\n"
            exit 1
        }
        if [ $project == "/var/www/predelanet" ]
        then
            {
                echo -e "Update prepared js for ${project}..."
                ./service/js.sh
                echo -e "OK\n"
            } || {
                echo -e "\nFailed to update prepared js... Please resolve that problem by hand\n"
                exit 1
            }
        fi
    else
        echo -e "Already update\n"
    fi
done

echo -e "All operations succeed\n"
exit 0