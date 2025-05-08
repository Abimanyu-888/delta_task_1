#!/usr/bin/bash
set -e


create_blog()
{
    local file="$1"
    touch ~/blogs/$file
    chmod 700 ~/blogs/$file
    echo "Enter categories from the following one by one"
    yq '.categories' ~/blogs.yaml
    local categories=()
    while read x
    do
    {
        categories+=($x)
    }
    done
    cat >> ~/blogs.yaml <<EOF
    - file_name: "${file}"
    publish_status: false
    cat_order: [${categories[@]}]
EOF
}
publish_blog()
{
    local file="$1"
    ln -s ~/blogs/$file ~/public/$file
    chmod 744 ~/blogs/$file
    yq -i "(.blogs[] | select(.file_name == \"$file\" )) |= (.publish_status = true)" ~/blogs.yaml
}
archive_blog()
{
    local file="$1"
    rm ~/public/$file
    chmod 700 ~/blogs/$file
    yq -i "(.blogs[] | select(.file_name == \"$file\" )) |= (.publish_status = false)" ~/blogs.yaml
}
delete_blog()
{
    local file="$1"
    rm ~/blogs/$file
    
    if find ~/public/$file &> /dev/null 
    then 
        rm ~/public/$file
        
    fi
    yq -i "del(.blogs[] | select(.file_name == \"$file\"))" ~/blogs.yaml
}
edit_blog()
{
    local file="$1"
    echo "Enter new categories from the following one by one"
    yq '.categories' ~/blogs.yaml
    local categories=()
    while read x
    do
    {
        categories+=($x)
    }
    done
    yq -i "(.blogs[] | select(.file_name == \"$file\" )) |= (.cat_order = [${categories[@]}])" ~/blogs.yaml

}

if [[ "$#" -eq 0 ]]
then
    echo "Use: $0 [-c to create blog file, -p to publish blog, -a to archive blog, -d to delete blog and -e to edit blog category]"
    exit 1

while [[ "$#" -gt 0 ]]
do
    case "$1" in
        -c)
            create_blog
            shift
            ;;
        -p)
            publish_file
            shift
            ;;
        -a)
            archive_file
            shift
            ;;
        -d)
            delete_blog
            shift
            ;;
        -e)
            edit_blog
            shift
            ;;
        *)
            echo "ERROR: Usage of unknown flag"
            echo "Use: $0 [-c to create blog file, -p to publish blog, -a to archive blog, -d to delete blog and -e to edit blog category]"
            exit 1
            ;;
    esac
done
