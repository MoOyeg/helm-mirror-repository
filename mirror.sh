#!/bin/bash

mirror_list="${mirror_list:-./mirror-list}"
temp_dir="${temp_dir:-./tempdir}"
last_n_versions="${last_n_versions:-3}"


vercomp () {
    #Source https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

qsort() {
   #Source https://stackoverflow.com/a/30576368
   (($#<=1)) && return 0
   local compare_fun=$1
   shift
   local stack=( 0 $(($#-1)) ) beg end i pivot smaller larger
   qsort_ret=("$@")
   while ((${#stack[@]})); do
      beg=${stack[0]}
      end=${stack[1]}
      stack=( "${stack[@]:2}" )
      smaller=() larger=()
      pivot=${qsort_ret[beg]}
      for ((i=beg+1;i<=end;++i)); do
         if "$compare_fun" "${qsort_ret[i]}" "$pivot"; then
            smaller+=( "${qsort_ret[i]}" )
         else
            larger+=( "${qsort_ret[i]}" )
         fi
      done
      qsort_ret=( "${qsort_ret[@]:0:beg}" "${smaller[@]}" "$pivot" "${larger[@]}" "${qsort_ret[@]:end+1}" )
      if ((${#smaller[@]}>=2)); then stack+=( "$beg" "$((beg+${#smaller[@]}-1))" ); fi
      if ((${#larger[@]}>=2)); then stack+=( "$((end-${#larger[@]}+1))" "$end" ); fi
   done
}

mirror_function() {

    if [[ -f ${1:-""} || -f ${2:-""}  || -f ${1:-""} ]]; then
        echo -e "Invalid Arguments\n"
        return 1
    fi

    #Sort the Chartversions
    chartversions=( $(helm search repo $2 -l | tail -n +2 | awk '{print $2}' ) )
    if [[ "$chartversions" == *"No results found"* ]] || [[ "$chartversions" == "" ]] ; then
        echo -e "Chart $2 not found in repo $1\n"
        return 1
    fi

    echo -e "Chart Versions Count: ${#chartversions[@]}\n"

    qsort vercomp "${chartversions[@]}"
    

    #Get and mirror the last N versions
    if [[ $last_n_versions -eq "0" ]]; then
        last_n_versions=${#qsort_ret[@]}
    fi

    for ((i=0; i<$last_n_versions; i++))
    do
        #Create a temp directory
        mkdir -p $temp_dir

        #Download the chart
        helm pull $2 --version "${qsort_ret[$i]}" --destination $temp_dir

        #Check if command failed
        if [[ $? -ne 0 ]]; then
            echo -e "Failed to download chart $2 with version ${qsort_ret[i]} from repo $1\n"
            continue
        fi

        #Push the chart to the mirror
        push_files=$(ls $temp_dir/*.tgz)
        if [[ $push_files == "" ]]; then
            echo -e "No charts found in $temp_dir\n"
            continue
        fi

        for file in ${push_files[@]}
        do
            helm push --insecure-skip-tls-verify $file oci://$3
            #Check if command failed
            if [[ $? -ne 0 ]]; then
            echo -e "Failed to push chart $2 with version ${qsort_ret[i]} to mirror $3\n"
            continue
            fi
        done

        #Remove the temp directory
        rm -rf $temp_dir

    done

}


#Read mirror_list File
while read line 
do
    #Check if the line is a comment
    if [[ $line == \#* ]] || [[ $line == "" ]]; then
        continue
    fi

    #Check if line is all spaces
    if [[ $line == " "* ]]; then
        continue
    fi

    #Extract the RepoName
    reponame=$(echo $line | cut -d' ' -f1)

    #Extract the URL
    url=$(echo $line | cut -d' ' -f2)

    #Extract the MirrorRepoName
    mirrorreponame=$(echo $line | cut -d' ' -f3)

    #Extract the ChartList
    chartlist=$(echo $line | cut -d' ' -f4)

    #Check if RepoName ,URL or mirrorreponame is empty
    if [[ $reponame == "" ]] || [[ $url == "" ]] || [[ $mirrorreponame == "" ]]; then
        echo -e "Invalid Line in mirror_list File\n"
        echo -e "Line: $line\n"
        continue
    fi

    #Check if chartlist is not Empty
    if ! [[ $chartlist == "" ]]; then
        #Convert Chartlist into Array
        IFSSAVE=$IFS
        IFS=","
        chartlist=($chartlist)
        IFS=$IFSSAVE
    fi

    #Add repo to helm
    helm repo add $reponame $url
    helm repo update $reponame

    #Check if command failed
    if [[ $? -ne 0 ]]; then
        echo -e "Failed to add repo $reponame with URL $url\n"
        continue
    fi

    #Capture list of Charts
    charts=$(helm search repo $reponame | awk '{print $1}' | grep -v NAME )
    
    #Loop through charts
    #Check if chartlist is not Empty
    if  [[ $charts == "" ]]; then
        continue
    else
        for chart in ${charts[@]}
        do
            #Check if chartlist is not Empty
            if ! [[ $chartlist == "" ]]; then
                chartfound="false"
                #Check if chart is in chartlist
                for chartname in ${chartlist[@]}        
                do
                    if [[ $chart == *"$chartname"* ]]; then
                        chartfound="true"
                        break
                    fi
                done

                if [[ $chartfound == "false" ]]; then
                    continue
                elif [[ $chartfound == "true" ]]; then
                    mirror_function $reponame $chart $mirrorreponame
                fi
            else
                mirror_function $reponame $chart $mirrorreponame

            fi



        done
    fi


done < $mirror_list
