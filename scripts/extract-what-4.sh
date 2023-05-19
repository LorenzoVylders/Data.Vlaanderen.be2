#!/bin/bash

# for debugging purposes
#set -x

extractwhat=$1
TARGETDIR=/tmp/workspace
CHECKOUTFILE=${TARGETDIR}/checkouts.txt
CONFIGDIR_DEFAULT=$( eval echo "${CIRCLE_WORKING_DIRECTORY}" )
CONFIGDIR=${2:-$CONFIGDIR_DEFAULT}


#############################################################################################
# extraction command functions

get_mapping_file() {
    local MAPPINGFILE=`jq -r 'if (.filename | length) > 0 then .filename else @sh "config/eap-mapping.json"  end' .publication-point.json`
    #local MAPPINGFILE="config/eap-mapping.json"
    if [ -f ".names.txt" ]
    then
	STR=".[] | select(.name == \"$(cat .names.txt)\") | [.]"
	jq "${STR}" ${MAPPINGFILE} > .names.json
	MAPPINGFILE=".names.json"
    fi
    echo ${MAPPINGFILE}
}



#############################################################################################
extract_stakeholder() {
    local MAPPINGFILE=$1
    local TDIR=${TARGETDIR}/ttl
    mkdir -p ${TDIR}
    jq -r '.[] | select(.type | contains("voc")) | @sh "python /app/specgen/generate_vocabulary.py --add_contributors --rdf /tmp/workspace/ttl/\(if .prefix then .prefix + "/" else "" end)\(.name).ttl --csv src/stakeholders.csv --csv_contributor_role_column \(.contributors) --output /tmp/workspace/ttl/\(if .prefix then .prefix + "/" else "" end)\(.name).ttl"' < $MAPPINGFILE | bash -e
}

#############################################################################################
# main one being worked on
extract_json() {
    local MAPPINGFILE=$1
    local LINE=$2
    local TDIR=${TARGETDIR}/json
    local RDIR=${TARGETDIR}/report
    local TTDIR=${TARGETDIR}/report/${LINE}
    mkdir -p ${TDIR} ${RDIR} ${TTDIR} ${TARGETDIR}/target/${LINE}

    local OUTPUTFILE=$(cat .names.txt).jsonld
    local DIAGRAM=$( jq .[].diagram .publication-point.json )
    local UMLFILE=$( jq .[].eap .publication-point.json )
    local SPECTYPE=$( jq .[].type .publication-point.json )
    local URLREF=$( jq .[].urlref .publication-point.json )
    local HOSTNAME=$( jq .hostname  ${CONFIGDIR}/config.json )
    

    oslo-converter-ea --umlFile ${UMLFILE} --diagramName ${DIAGRAM} --outputFile ${OUTPUTFILE} \
	         --specificationType ${SPECTYPE} --versionId ${URLREF} --baseURI ${HOSTNAME} \
		 &> ${TTDIR}/$(cat .names.txt).report


#   exit code of java program is not reliable for detecting processing error
#    if  [ $? -eq 0 ] ; then
#   the content is also not reliable as it contains error when there are business errors
#    if cat ${TTDIR}/$(cat .names.txt).report | grep "error" 
#    then
#       echo "extract_json: ERROR EA-to-RDF ended in an error"
#       cat ${TTDIR}/$(cat .names.txt).report
#       exit -1 ;
#    fi
    if [ ! -f "$(cat .names.txt).jsonld" ]
    then
        echo "extract_json: $(cat .names.txt).jsonld was not created"
        cat  ${TTDIR}/$(cat .names.txt).report
        exit -1;
    fi
    jq . $(cat .names.txt).jsonld &> /dev/null
    if [ ! $? -eq 0 ] || [ ! -s  $(cat .names.txt).jsonld ]; then
        echo "extract_json: ERROR EA-to-RDF ended in an error"
        cat ${TTDIR}/$(cat .names.txt).report
            exit -1 ;
    fi

    cat .publication-point.json
    jq -s '.[0] + .[1][0] + .[2]' $(cat .names.txt).jsonld $MAPPINGFILE .publication-point.json > ${TTDIR}/all-$(cat .names.txt).jsonld ## the sum in jq overwrites the value for .contributors
    cp $(cat .names.txt).jsonld ${TTDIR}
    ## overwrite the content with the aggregated version
    cp ${TTDIR}/all-$(cat .names.txt).jsonld  $(cat .names.txt).jsonld 
    cp $(cat .names.txt).report ${RDIR}
    ( echo $PWD ; cat ${TTDIR}/$(cat .names.txt).report ) >> ${RDIR}/ALL.report
}

#############################################################################################
# do the conversions

if [ ! -f "${CHECKOUTFILE}" ]
then
    # normalise the functioning
    echo $CWD > ${CHECKOUTFILE}
fi

cat ${CHECKOUTFILE} | while read line
do
    SLINE=${TARGETDIR}/src/${line}
    echo "Processing line ($extractwhat): ${SLINE}"
    if [ -d "${SLINE}" ]
    then
      pushd ${SLINE}
       MAPPINGFILE=$(get_mapping_file)   
       cat $MAPPINGFILE

       # determine the EAP config files to be used
       # if present use the repository ones, otherwise the definied by the publication environment
       jq -r '.[0] | if has("config") then empty else  @sh "cp ~/project/config/config-\(.type).json config" end ' < $MAPPINGFILE | bash 
       jq 'def maybe(k): if has(k) then { (k) : .[k] } else { (k) : "config/config-\(.type).json" } end; .[0] |= . + maybe("config")' $MAPPINGFILE > /tmp/mapfile
       cp /tmp/mapfile $MAPPINGFILE
       case $extractwhat in
	      jsonld) extract_json $MAPPINGFILE $line
		      ;;
        stakeholders) extract_stakeholder $MAPPINGFILE
		      ;;
                   *) echo "ERROR: $extractwhat not defined"
        esac
      popd
    else
      echo "Error: ${SLINE}" >> log.txt
    fi
done

