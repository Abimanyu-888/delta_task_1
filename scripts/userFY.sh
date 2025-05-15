#!/usr/bin/bash
set -e

users_username=($(yq  '.users[].username' "/opt/blog_server/files/userpref.yaml"))
declare -A category
category["Sports"]=1
category["Cinema"]=2
category["Technology"]=3
category["Travel"]=4
category["Food"]=5
category["Lifestyle"]=6
category["Finance"]=7

declare -A user_pref
user_count=0
for theuser in ${users_username[@]}
do
    rm -f /home/users/$theuser/For_You/* &> /dev/null
    rm -f /home/users/$theuser/FYI.yaml &> /dev/null
    touch /home/users/$theuser/FYI.yaml
    cat > /home/users/$theuser/FYI.yaml <<EOF
User_Preferred_Blogs:
EOF
    user_pref["$theuser"1]=${category[$(yq ".users[] | select(.username == \"$theuser\" ).pref1" "/opt/blog_server/files/userpref.yaml")]}
    user_pref["$theuser"2]=${category[$(yq ".users[] | select(.username == \"$theuser\" ).pref2" "/opt/blog_server/files/userpref.yaml")]}
    user_pref["$theuser"3]=${category[$(yq ".users[] | select(.username == \"$theuser\" ).pref3" "/opt/blog_server/files/userpref.yaml")]}
    (( user_count++ ))
done

declare -A blog_cat
declare -A blog_assign
blog_count=0
for blog in /home/authors/*/public/*
do
    blog_name=$(realpath $blog | cut -d/ -f6 )
    author=$(realpath $blog | cut -d/ -f4 )
    blog_cat["$author$blog_name"1]=$(echo $blog_name | cut -d. -f3)
    blog_cat["$author$blog_name"2]=$(echo $blog_name | cut -d. -f4)
    blog_cat["$author$blog_name"3]=$(echo $blog_name | cut -d. -f5)
    blog_assin["$author$blog_name"]=0
    (( blog_count++ ))
done

declare -A user_blog_score
for theuser in ${users_username[@]}
do
    for blog in /home/authors/*/public/*
    do
        blog_name=$(realpath $blog | cut -d/ -f6 )
        author=$(realpath $blog | cut -d/ -f4 )
        user_blog_score["$theuser$author$blog_name"]=0
        for i in {1..3}
        do 
            for j in {1..3}
            do 
                if [[ ${user_pref["$theuser"$i]} -eq ${blog_cat["$author$blog_name"$j]} ]]
                then
                    (( user_blog_score["$theuser$author$blog_name"]+= ((4-i)*3) -j+1 ))
                fi
            done
        done
    done
done


if [[ blog_count -le 3 ]]
then 
    for theuser in ${users_username[@]}
    do
        for blog in /home/authors/*/public/*
        do
            blog_name=$(realpath $blog | cut -d/ -f6 )
            author=$(realpath $blog | cut -d/ -f4 )
            ln -s /home/authors/$author/public/$blog_name /home/users/$theuser/For_You/$blog_name
            yq -i "(.User_Preferred_Blogs += [\"$blog_name\"])" /home/users/$theuser/FYI.yaml
        done
    done
else
    for theuser in $(shuf -e ${users_username[@]} )
    do
        pick_author=(0 0 0)
        pick_blog=(0 0 0)
        pick_value=(0 0 0)
        for blog in /home/authors/*public/*
        do
            blog_name=$(realpath $blog | cut -d/ -f6 )
            author=$(realpath $blog | cut -d/ -f4 )
            if [[ user_blog_score["$thuser$author$blog_name"] -ge pick_value[0] ]]
            then
                pick_value[2]=${pick_value[1]}; pick_author[2]=${pick_author[1]}; pick_blog[2]=${pick_blog[1]}
                pick_value[1]=${pick_value[0]}; pick_author[1]=${pick_author[0]}; pick_blog[1]=${pick_blog[0]}
                pick_value[0]=${user_blog_score["$thuser$author$blog_name"]}; pick_author[0]=$author; pick_blog[0]=$blog_name
            elif [[ user_blog_score["$thuser$author$blog_name"] -ge pick_value[1] ]]
            then
                pick_value[2]=${pick_value[1]}; pick_author[2]=${pick_author[1]}; pick_blog[2]=${pick_blog[1]}
                pick_value[1]=${user_blog_score["$thuser$author$blog_name"]}; pick_author[1]=$author; pick_blog[1]=$blog_name
            elif [[ user_blog_score["$thuser$author$blog_name"] -ge pick_value[2] ]]
            then
                pick_value[2]=${user_blog_score["$thuser$author$blog_name"]}; pick_author[2]=$author; pick_blog[2]=$blog_name
            fi
        done
        for i in {0..2}
        do
            ln -s /home/authors/${pick_author[$i]}/public/${pick_blog[$i]} /home/users/$theuser/For_You/${pick_blog[$i]}
            yq -i "(.User_Preferred_Blogs += [\"${pick_blog[$i]}\"])" /home/users/$theuser/FYI.yaml
        done
    done
fi



        

