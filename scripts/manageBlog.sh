#!/usr/bin/bash
set -e


create_blog()
{
    local file="$1"

    echo "Enter categories from the following one by one"
    yq '.categories' ~/blogs.yaml
    local categories=()
    for ((i=1; i<=3; i++)) 
    do
        read x
        categories+=("$x")
    done
    touch ~/blogs/$file.${categories[0]}.${categories[1]}.${categories[2]}
    chmod 700 ~/blogs/$file.${categories[0]}.${categories[1]}.${categories[2]}
    local new_name=$file.${categories[0]}.${categories[1]}.${categories[2]}
    cat >> ~/blogs.yaml <<EOF
    - file_name: "${new_file}"
    publish_status: false
    cat_order: [${categories[@]}]
EOF
}
publish_blog()
{
    local file="$1"
    touch ~/public/$file
    chmod 744 ~/blogs/$file
    chmod 111 ~/public/$file

    cat > ~/public/$file <<EOF
#!/usr/bin/bash
echo "\$(date '+%d-%m-%Y %H:%M:%S') $file Opened_published_by $(whoami)" >> /var/log/blog_server/blog_access.log
cat /home/authors/$(whoami)/blogs/$file
EOF
    echo "$(date '+%d-%m-%Y %H:%M:%S') $(whoami) published $file" >> /var/log/blog_server/blog_publish.log
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
        echo "$(date '+%d-%m-%Y %H:%M:%S') $(whoami) published $file deleted" >> /var/log/blog_server/blog_delete.log
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
    mv ~/blogs/$file ~/blogs/$file.${categories[0]}.${categories[1]}.${categories[2]}
    local new_name=$file.${categories[0]}.${categories[1]}.${categories[2]}
    yq -i "(.blogs[] | select(.file_name == \"$file\" )) |= (.cat_order = [${categories[@]}]) |= (.file_name = \"$new_name\" )" ~/blogs.yaml

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
