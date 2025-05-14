#!/usr/bin/bash
set -e

users_username=($(yq -r '.users[].username' "users.yaml" ))
authors_username=($(yq -r '.authors[].username' "users.yaml"))
mods_username=($(yq -r '.mods[].username' "users.yaml"))
admins_username=($(yq -r '.admins[].username' "users.yaml"))

mkdir -p /home/users
mkdir -p /home/authors
mkdir -p /home/mods
mkdir -p /home/admin

for thegroup in g_user g_author g_mod g_admin
do
    ! getent group "$thegroup" &> /dev/null && sudo groupadd $thegroup
done

for theuser in ${users_username[@]}
do
    if ! id $theuser &> /dev/null 
    then
        useradd $theuser -d /home/users/$theuser -s /bin/bash -g g_user
        mkdir -p /home/users/$theuser/all_blogs
        mkdir -p /home/users/$theuser/For_You
        touch /home/users/$theuser/FYI.yaml
        chmod 700 /home/users/$theuser
        chown $theuser:g_user -R /home/users/$theuser
    elif ! getent group g_user | grep -w $theuser &> /dev/null
    then 
        usermod -aG g_user $theuser
        usermod -U $theuser
    fi
done

for theuser in ${authors_username[@]}
do
    if ! id $theuser &> /dev/null
    then
        useradd $theuser -d /home/authors/$theuser -s /bin/bash -g g_author
        mkdir -p /home/authors/$theuser/blogs
        mkdir -p /home/authors/$theuser/public
        touch /home/authors/$theuser/blogs.yaml
        chmod 700 /home/authors/$theuser/blogs.yaml
        cat > /home/authors/$theuser/blogs.yaml <<EOF
categories:
    1: "Sports"
    2: "Cinema"
    3: "Technology"
    4: "Travel"
    5: "Food"
    6: "Lifestyle"
    7: "Finance"
blogs:
EOF
        chmod 701 /home/authors/$theuser
        chmod 705 /home/authors/$theuser/public
        chown $theuser:g_author -R /home/authors/$theuser
        chown root:g_admin /home/authors/$theuser/blogs.yaml
    elif ! getent group g_author | grep -w $theuser &> /dev/null
    then 
        usermod -aG g_author $theuser
        usermod -U $theuser
    fi
done


for theuser in ${users_username[@]}
do
    for norm_user in ${users_username[@]}
    do
        ln -s /home/authors/$theuser/public /home/users/$norm_user/all_blogs/$theuser 2> /dev/null
    done
done


for theuser in ${mods_username[@]}
do
    if ! id $theuser &> /dev/null
    then
        useradd $theuser -d /home/mods/$theuser -s /bin/bash -g g_mod
        mkdir -p /home/mods/$theuser/blacklist.txt
        chmod 700 /home/mods/$theuser
        chown $theuser:g_mod -R /home/mods/$theuser
        assign_authors=$(yq -r ".mods[] | select(.username == \"$theuser\" ).authors[]" "users.yaml" )
        for theauthor in ${assign_authors[@]}
        do
            setfacl -m u:$theuser:rwx /home/authors/$theauthor/public
            ln -s /home/authors/$theauthor/public /home/mods/$theuser/$theauthor 2> /dev/null
        done
    fi
done

for theuser in ${admins_username[@]}
do
    if ! id $theuser &> /dev/null
    then
        useradd $theuser -d /home/admin/$theuser -s /bin/bash -g g_admin
        mkdir -p /home/admin/$theuser
        chmod 700 /home/admin/$theuser
        chown $theuser:g_admin -R /home/admin/$theuser
        usermod -aG g_user,g_author,g_mod $theuser
        setfacl -R -m u:$theuser:rwx /home/users/*
        setfacl -R -m u:$theuser:rwx /home/authors/*
        setfacl -R -m u:$theuser:rwx /home/mods/*
        setfacl -R -m u:$theuser:rwx /home/admin/*
    fi
done

if [ -f /etc/g_user_members.txt ]
then
    echo ${users_username[@]} | tr ' ' '\n'| sort > current.txt
    tr ',' '\n' < /etc/g_user_members.txt | sort > previous.txt
    while read $theuser
    do
        gpasswd -d $theuser g_user
        usermod -L $theuser
    done < comm -13 current.txt previous.txt

    echo ${authors_username[@]} | tr -d '"' | tr ' ' '\n'| sort > current.txt
    tr ',' '\n' < /etc/g_author_members.txt | sort > previous.txt
    while read $theuser
    do
        rm -R /home/user/*/all_blogs/$theuser
        
        gpasswd -d $theuser g_author
        usermod -L $theuser
    done < comm -13 current.txt previous.txt

    echo ${mods_username[@]} | tr -d '"' | tr ' ' '\n'| sort > current.txt
    tr ',' '\n' < /etc/g_mod_members.txt | sort > previous.txt
    while read $theuser
    do
        gpasswd -d $theuser g_mod
        usermod -L $theuser
    done < comm -13 current.txt previous.txt

    content=${admins_username[@]}
    # strip ALL whitespace; what remains is “real” content
    stripped=${content//[[:space:]]/}
    if [[ ! -z $stripped ]]
    then
        echo ${admins_username[@]} | tr -d '"' | tr ' ' '\n'| sort > current.txt
        tr ',' '\n' < /etc/g_admin_members.txt | sort > previous.txt
        while read $theuser
        do
            gpasswd -d $theuser g_admin
            usermod -L $theuser
        done < comm -13 current.txt previous.txt
    else
        echo "need atleast one member in admin required"
    fi
fi

getent group g_user | cut -d: -f4 | tee /etc/g_user_members.txt &> /dev/null
getent group g_author | cut -d: -f4 | tee /etc/g_author_members.txt &> /dev/null
getent group g_mod | cut -d: -f4 | tee /etc/g_mod_members.txt &> /dev/null
getent group g_admin | cut -d: -f4 | tee /etc/g_admin_members.txt &> /dev/null


if [[ ! -d /var/log/blog_server ]]
then
    mkdir /var/log/blog_server
    touch /var/log/blog_server/blog_access.log; chmod 752 /var/log/blog_server/blog_access.log
    touch /var/log/blog_server/blog_publish.log; chmod 752 /var/log/blog_server/blog_publish.log
    touch /var/log/blog_server/blog_delete.log; chmod 752 /var/log/blog_server/blog_delete.log
fi