#!/bin/bash

if [[ $# -ne 1 && -d "$1" ]]
then
    echo "use: $0 <author_blog_dir>"
    exit 1
fi
blog_dir="$1"
dir_real_path=$(realpath $1)


for i in "$blog_dir"/*
do
    count=0
    while IFS= read -r word || [ -n "$word" ]; do
        replace_star=$(printf "%${#word}s" | tr ' ' '*')
        line_no=$(grep -i -n "$word" "$i" | cut -d: -f1 )
        if grep -q -i "$word" "$i" 
        then
            echo "Found blacklisted word $word in "$i" at the line no/nos ${line_no[@]}"
            ((count++))
        fi
        sed -i "s/$word/$replace_star/gI" "$i"

    done < "~/blacklist.txt"
    if [[ count -eq 5 ]]
    then
        author_name=$( echo $dir_real_path | cut -d/ -f4 )
        file_name=$( echo $dir_real_path | cut -d/ -f6 )
        rm /home/authors/$author_name/public/$file_name
        chmod 700 /home/authors/$author_name/blogs/$file_name
        export count
        yq -i '(.blogs[] | select(.file_name == \"$file\" )) |= (.publish_status = false) |= (.mod_comments = "found " + env(count) + " blacklist words" )' /home/authors/$author_name/blogs.yaml
        echo "Blog $file_name is archived due to excessive blacklisted words."
    fi
done