#!/usr/bin/bash
set -e


echo -e "Blogs published details:\n\n"
cat /var/log/blog_server/blog_publish.log

echo -e "Blogs deleted details:\n\n"
cat /var/log/blog_server/blog_delete.log

echo "TOP 3 read blogs:"
declare -A blog_count
while read date time blog info author
do
    ((blog_count["$author_$blog"]++))
done < /var/log/blog_server/blog_access.log

top_score=(0 0 0)
top_blog=(0 0 0)
for key in "${!blog_count[@]}"
do
    if [[ ${blog_count["$key"]} -ge ${top_score[0]} ]]
    then
        blog_info=$(echo $key)
        top_score[2]=${top_score[1]}; top_blog[2]=${top_blog[1]}
        top_score[1]=${top_score[0]}; top_blog[1]=${top_blog[0]}
        top_score[0]=${blog_count["$key"]}; top_blog[0]=$blog_info
    elif [[ ${blog_count["$key"]} -ge ${top_score[1]} ]]
    then
        top_score[2]=${top_score[1]}; top_blog[2]=${top_blog[1]}
        top_score[1]=${blog_count["$key"]}; top_blog[1]=$blog_info
    elif [[ ${blog_count["$key"]} -ge ${top_score[2]} ]]
    then
        top_score[2]=${blog_count["$key"]}; top_blog[2]=$blog_info
    fi
done
for i in {0..2}
do
    blog_count=$(echo ${top_blog[$i]} | cut -d_ -f2 )
    author_name=$(echo ${top_blog[$i]} | cut -d_ -f1 )
    echo "$((i+1)) : $blog_count by $author_name"
done