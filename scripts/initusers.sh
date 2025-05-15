#!/usr/bin/bash
set -e
trap 'echo "Error on line $LINENO"; exit 1' ERR


if [[ ! -d /home/users ]] #doing initial setup for the blog_server (one_time only)
then
    sudo groupadd g_user
    sudo groupadd g_author
    sudo groupadd g_mod
    sudo groupadd g_admin


    mkdir -p /home/users
    mkdir -p /home/authors
    mkdir -p /home/mods
    mkdir -p /home/admin


    #adding scripts to path and giving appropriate premissions to the scripts
    dir_path="$(dirname "$(dirname "$(realpath "$0")")")"
    mkdir -p /opt/blog_server/scripts
    mkdir -p /opt/blog_server/files
    cp -r $dir_path/scripts/* /opt/blog_server/scripts/
    cp -r $dir_path/files/* /opt/blog_server/files/
    chown root:g_admin -R /opt/blog_server
    chmod -R 770 /opt/blog_server
    setfacl -m g:g_author:rx /opt/blog_server /opt/blog_server/scripts /opt/blog_server/scripts/manageBlog.sh
    setfacl -m g:g_mod:rx /opt/blog_server /opt/blog_server/scripts /opt/blog_server/scripts/blogFilter.sh
    echo 'export PATH=$PATH:/opt/blog_server/scripts' | sudo tee /etc/profile.d/blog_server.sh
    chmod +x /etc/profile.d/blog_server.sh


    #creating log files for the report 
    mkdir /var/log/blog_server
    touch /var/log/blog_server/blog_access.log; chmod 752 /var/log/blog_server/blog_access.log
    touch /var/log/blog_server/blog_publish.log; chmod 752 /var/log/blog_server/blog_publish.log
    touch /var/log/blog_server/blog_delete.log; chmod 752 /var/log/blog_server/blog_delete.log
fi

#getting users form the users.yaml file
users_username=($(yq -r '.users[].username' "/opt/blog_server/files/users.yaml" ))
authors_username=($(yq -r '.authors[].username' "/opt/blog_server/files/users.yaml"))
mods_username=($(yq -r '.mods[].username' "/opt/blog_server/files/users.yaml"))
admins_username=($(yq -r '.admins[].username' "/opt/blog_server/files/users.yaml"))



for theuser in ${users_username[@]}
do
    if ! id $theuser &> /dev/null #first time user creation
    then
        useradd $theuser -d /home/users/$theuser -s /bin/bash -g g_user
        echo "$theuser:$theuser" | chpasswd # username is their temporary passwd
        passwd -e "$theuser" &> /dev/null
        mkdir -p /home/users/$theuser/all_blogs
        mkdir -p /home/users/$theuser/For_You
        touch /home/users/$theuser/FYI.yaml
        chown $theuser:g_user -R /home/users/$theuser
        chmod 700 /home/users/$theuser
    elif ! getent group g_user | grep -w $theuser &> /dev/null #if the user was removed and now added again
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
        echo "$theuser:$theuser" | chpasswd # username is their temporary passwd
        passwd -e "$theuser" &> /dev/null
        mkdir -p /home/authors/$theuser/blogs
        mkdir -p /home/authors/$theuser/public
        touch /home/authors/$theuser/blogs.yaml
        chown $theuser:g_author -R /home/authors/$theuser
        chmod 701 /home/authors/$theuser
        chmod 705 /home/authors/$theuser/public


        chmod 644 /home/authors/$theuser/blogs.yaml
        setfacl -m g:g_mod:rw /home/authors/$theuser/blogs.yaml

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

    elif ! getent group g_author | grep -w $theuser &> /dev/null
    then 
        usermod -aG g_author $theuser
        usermod -U $theuser
    fi
done


for theuser in ${authors_username[@]}
do
    for norm_user in ${users_username[@]}
    do
        ln -s /home/authors/$theuser/public /home/users/$norm_user/all_blogs/$theuser 2> /dev/null || true
    done
done


for theuser in ${mods_username[@]}
do
    if ! id $theuser &> /dev/null
    then
        useradd $theuser -d /home/mods/$theuser -s /bin/bash -g g_mod
        echo "$theuser:$theuser" | chpasswd # username is their temporary passwd
        passwd -e "$theuser" &> /dev/null
        touch -p /home/mods/$theuser/blacklist.txt
        cp /opt/blog_server/files/blacklist.txt /home/mods/$theuser/blacklist.txt
        chmod 700 /home/mods/$theuser
        chown $theuser:g_mod -R /home/mods/$theuser
        assign_authors=$(yq -r ".mods[] | select(.username == \"$theuser\" ).authors[]" "/opt/blog_server/files/users.yaml" )
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
        echo "$theuser:$theuser" | chpasswd # username is their temporary passwd
        passwd -e "$theuser" &> /dev/null
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

    echo in
    echo ${users_username[@]} | tr ' ' '\n'| sort > current.txt
    tr ',' '\n' < /etc/g_user_members.txt | sort > previous.txt
    comm -1 -3 current.txt previous.txt | while read theuser
    do
        gpasswd -d $theuser g_user
        usermod -L $theuser
    done 

    echo ${authors_username[@]} | tr -d '"' | tr ' ' '\n'| sort > current.txt
    tr ',' '\n' < /etc/g_author_members.txt | sort > previous.txt
    comm -1 -3 current.txt previous.txt | while read theuser
    do
        rm -R /home/users/*/all_blogs/$theuser
        gpasswd -d $theuser g_author
        usermod -L $theuser
    done 

    echo ${mods_username[@]} | tr -d '"' | tr ' ' '\n'| sort > current.txt
    tr ',' '\n' < /etc/g_mod_members.txt | sort > previous.txt
    comm -1 -3 current.txt previous.txt | while read theuser
    do
        gpasswd -d $theuser g_mod
        usermod -L $theuser
    done 

    content=${admins_username[@]}
    # strip ALL whitespace; what remains is “real” content
    stripped=${content//[[:space:]]/}
    if [[ ! -z $stripped ]]
    then
        echo ${admins_username[@]} | tr -d '"' | tr ' ' '\n'| sort > current.txt
        tr ',' '\n' < /etc/g_admin_members.txt | sort > previous.txt
        comm -1 -3 current.txt previous.txt | while read theuser
        do
            gpasswd -d $theuser g_admin
            usermod -L $theuser
        done 
    else
        echo "need atleast one member in admin required"
    fi
fi

getent group g_user | cut -d: -f4 | tee /etc/g_user_members.txt &> /dev/null
getent group g_author | cut -d: -f4 | tee /etc/g_author_members.txt &> /dev/null
getent group g_mod | cut -d: -f4 | tee /etc/g_mod_members.txt &> /dev/null
getent group g_admin | cut -d: -f4 | tee /etc/g_admin_members.txt &> /dev/null
