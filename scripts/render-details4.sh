#!/bin/bash

TARGETDIR=$1
DETAILS=$2
CONFIGDIR=$3

PRIMELANGUAGECONFIG=$(jq -r .primeLanguage ${CONFIGDIR}/config.json)
GOALLANGUAGECONFIG=$(jq -r '.otherLanguages | @sh' ${CONFIGDIR}/config.json)
GOALLANGUAGECONFIG=$(echo ${GOALLANGUAGECONFIG} | sed -e "s/'//g")

PRIMELANGUAGE=${4-${PRIMELANGUAGECONFIG}}
GOALLANGUAGE=${5-${GOALLANGUAGECONFIG}}

STRICT=$(jq -r .toolchain.strickness ${CONFIGDIR}/config.json)
HOSTNAME=$(jq -r .hostname ${CONFIGDIR}/config.json)

CHECKOUTFILE=${TARGETDIR}/checkouts.txt
export NODE_PATH=/app/node_modules

execution_strickness() {
    if [ "${STRICT}" != "lazy" ]; then
        exit -1
    fi
}

generator_parameters() {

    local GENERATOR=$1
    local JSONI=$2

    #
    # The toolchain can add specific parameters for the SHACL generation tool
    # Priority rules are as follows:
    #   1. publication point specific
    #   2. generic configuration
    #   3. otherwise empty string
    #
    COMMAND=$(echo '.'${GENERATOR}'.parameters')
    PARAMETERS=$(jq -r ${COMMAND} ${JSONI})
    if [ "${PARAMETERS}" == "null" ]; then
        PARAMETERS=$(jq -r ${COMMAND} ${CONFIGDIR}/config.json)
    fi
    if [ "${PARAMETERS}" == "null" ] || [ -z "${PARAMETERS}" ]; then
        PARAMETERS=""
    fi
}

generate_for_language() {

    local LANGUAGE=$1
    local JSONI=$2

    #
    # test if the generator should be executed for this language
    #
    # if config.toolchain.autotranslate = true then apply the generator for any language in config.otherLanguages
    # if config.toolchain.autotranslate = false then apply the generator if the JSONI.translation contains the language
    # otherwise false
    #
    AUTOTRANSLATE=$(jq -r .toolchain.autotranslate ${CONFIGDIR}/config.json)

    if [ ${AUTOTRANSLATE} == true ]; then

        OTHERCOMMAND=$(echo '.otherLanguages | contains(["'${LANGUAGE}'"])')
        OTHER=$(jq -r "${OTHERCOMMAND}" ${CONFIGDIR}/config.json)
        if [ "${OTHER}" == "true" ] || [ "${OTHER}" == true ]; then
            GENERATEDARTEFACT=true
        else
            GENERATEDARTEFACT=false
        fi
    else
        COMMANDLANGJSON=$(echo '.translation | .[] | select(.language | contains("'${LANGUAGE}'")) | .translationjson')
        TRANSLATIONFILE=$(jq -r "${COMMANDLANGJSON}" ${JSONI})
        if [ "${TRANSLATIONFILE}" == "" ] || [ "${TRANSLATIONFILE}" == "null" ]; then
            GENERATEDARTEFACT=false
        else
            GENERATEDARTEFACT=true
        fi

    fi

}

REPORTLINEPREFIX='#||#'
check_tool_output_for_non_emptiness() {
	local REPORT=$1

	sed  "/${REPORTLINEPREFIX}/d" $REPORT > /tmp/out

}


render_merged_files() {
    echo "Merge the translation file for language $2 with the source $3"
    local PRIMELANGUAGE=$1
    local GOALLANGUAGE=$2
    local JSONI=$3
    local SLINE=$4
    local TRLINE=$5
    local RLINE=$6

    FILENAME=$(jq -r ".name" ${JSONI})
    GOALFILENAME=${FILENAME}_${GOALLANGUAGE}.json

    COMMANDLANGJSON=$(echo '.translation | .[] | select(.language | contains("'${GOALLANGUAGE}'")) | .translationjson')
    TRANSLATIONFILE=$(jq -r "${COMMANDLANGJSON}" ${JSONI})
    # secure the case that the translation file is not mentioned
    if [ "${TRANSLATIONFILE}" == "" ] || [ "${TRANSLATIONFILE}" == "null" ]; then
        # if there is no translation file defined in the config then
        # continue the creation of a merge only if there auto-translation is switched on
        # TODO: implemenet options
        TRANSLATIONFILE=${GOALFILENAME}
    fi

    AUTOTRANSLATE=$(jq -r .toolchain.autotranslate ${CONFIGDIR}/config.json)
    if [ ${AUTOTRANSLATE} == true ]; then
        INPUTTRANSLATIONFILE=${TLINE}/autotranslation/${TRANSLATIONFILE}
    else
    	# assume that previously the translation files have been copied to the target
    	# we must ensure that the relative directory from OSLOthema repo is followed
    	INPUTTRANSLATIONFILE=${TLINE}/translation/${TRANSLATIONFILE}
    fi


    if [ -f "${INPUTTRANSLATIONFILE}" ]; then
        echo "A translation file ${TRANSLATIONFILE} exists."
	sed -i -e "s/${GOALLANGUAGE}-t-${PRIMELANGUAGE}/${GOALLANGUAGE}/g" ${INPUTTRANSLATIONFILE}
    fi

    mkdir -p ${RLINE}/merged
    MERGEDFILENAME=merged_${FILENAME}_${GOALLANGUAGE}.jsonld
    MERGEDFILE=${RLINE}/merged/${MERGEDFILENAME}

    if [ "${PRIMELANGUAGE}" == "${GOALLANGUAGE}" ]; then
        echo "The primelanguage and the goallanguage are the same:  nothing to merge. Just copy it"
        cp ${JSONI} ${MERGEDFILE}

    else
        if [ -f "${INPUTTRANSLATIONFILE}" ]; then
            echo "${INPUTTRANSLATIONFILE} exists, the files will be merged."
            echo "RENDER-DETAILS(mergefile): node /app/translation-json-update.js -i ${JSONI} -f ${TRANSLATIONFILE} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${MERGEDFILE}"
            if ! node /app/translation-json-update.js -i ${JSONI} -f ${INPUTTRANSLATIONFILE} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${MERGEDFILE}; then
                echo "RENDER-DETAILS: failed"
                execution_strickness
            else
                echo "RENDER-DETAILS: Files succesfully merged and saved to: ${MERGEDFILE}"
                prettyprint_jsonld ${MERGEDFILE}
            fi
        else
            echo "${INPUTTRANSLATIONFILE} does not exist, nothing to merge. Just copy it"
            cp ${JSONI} ${MERGEDFILE}
        fi
    fi
}

render_metadata() {
    echo "create metadata for language $1 for $2 in the directory $5"
    local GOALLANGUAGE=$1
    local JSONI=$2
    local DROOT=$3
    local SLINE=$4
    local TLINE=$5

    FILENAME=$(jq -r ".name" ${JSONI})
    METAOUTPUTFILENAME=meta_${FILENAME}.json
    mkdir -p ${TLINE}/html
    METAOUTPUT=${TLINE}/html/${METAOUTPUTFILENAME}

        if ! node /app/html-metadata-generator.js -i ${JSONI} -m ${GOALLANGUAGE} -h ${HOSTNAME} -r /${DROOT} -o ${METAOUTPUT}; then
            echo "RENDER-DETAILS: failed"
            execution_strickness
        else
            echo "RENDER-DETAILS: metadata file succesfully updated"
            pretty_print_json ${METAOUTPUT}
        fi

}

render_translationfiles() {
    echo "create translations for primelanguage $1, goallanguage $2 and file $3 in the directory $4"
    local PRIMELANGUAGE=$1
    local GOALLANGUAGE=$2
    local JSONI=$3
    local SLINE=$4
    local TLINE=$5

    FILENAME=$(jq -r ".name" ${JSONI})
    PRIMEOUTPUTFILENAME=${FILENAME}_${PRIMELANGUAGE}.json
    GOALOUTPUTFILENAME=${FILENAME}_${GOALLANGUAGE}.json

    COMMANDLANGJSON=$(echo '.translation | .[] | select(.language | contains("'${GOALLANGUAGE}'")) | .translationjson')
    TRANSLATIONFILE=$(jq -r "${COMMANDLANGJSON}" ${JSONI})
    # secure the case that the translation file is not mentioned
    if [ "${TRANSLATIONFILE}" == "" ] || [ "${TRANSLATIONFILE}" == "null" ]; then
        TRANSLATIONFILE=${GOALOUTPUTFILENAME}
    fi

    mkdir -p ${TLINE}/translation
    INPUTTRANSLATIONFILE=${SLINE}/translation/${TRANSLATIONFILE}
    OUTPUTTRANSLATIONFILE=${TLINE}/translation/${TRANSLATIONFILE}

    if [ -f "${INPUTTRANSLATIONFILE}" ]; then
        echo "A translation file ${TRANSLATIONFILE} exists."
        echo "UPDATE the translation file: node /app/translation-json-generator.js -i ${FILE} -f ${JSONI} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${OUTPUTFILE}"
        if ! node /app/translation-json-generator.js -i ${JSONI} -t ${INPUTTRANSLATIONFILE} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${OUTPUTTRANSLATIONFILE}; then
            echo "RENDER-DETAILS: failed"
            execution_strickness
        else
            echo "RENDER-DETAILS: translation file succesfully updated"
            pretty_print_json ${OUTPUTTRANSLATIONFILE}
        fi
    else
        echo "NO translation file ${TRANSLATIONFILE} exists"
        echo "CREATE a translation file: node /app/translation-json-generator.js -i ${JSONI} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${OUTPUTTRANSLATIONFILE}"
        if ! node /app/translation-json-generator.js -i ${JSONI} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${OUTPUTTRANSLATIONFILE}; then
            echo "RENDER-DETAILS: failed"
            execution_strickness
        else
            echo "RENDER-DETAILS: translation file succesfully created"
            pretty_print_json ${OUTPUTTRANSLATIONFILE}
        fi
    fi
}


autotranslatefiles() {
    echo "translate for primelanguage $1, goallanguage $2 and file $3 in the directory $4"
    local PRIMELANGUAGE=$1
    local GOALLANGUAGE=$2
    local JSONI=$3
    local SLINE=$4
    local TLINE=$5

    FILENAME=$(jq -r ".name" ${JSONI})
    PRIMEOUTPUTFILENAME=${FILENAME}_${PRIMELANGUAGE}.json
    GOALOUTPUTFILENAME=${FILENAME}_${GOALLANGUAGE}.json

    COMMANDLANGJSON=$(echo '.translation | .[] | select(.language | contains("'${GOALLANGUAGE}'")) | .translationjson')
    TRANSLATIONFILE=$(jq -r "${COMMANDLANGJSON}" ${JSONI})
    # secure the case that the translation file is not mentioned
    if [ "${TRANSLATIONFILE}" == "" ] || [ "${TRANSLATIONFILE}" == "null" ]; then
        TRANSLATIONFILE=${GOALOUTPUTFILENAME}
    fi

    mkdir -p ${TLINE}/autotranslation
    INPUTTRANSLATIONFILE=${TLINE}/translation/${TRANSLATIONFILE}
    OUTPUTTRANSLATIONFILE=${TLINE}/autotranslation/${TRANSLATIONFILE}

    if [ -f "${INPUTTRANSLATIONFILE}" ]; then
        echo "A translation file ${TRANSLATIONFILE} exists."
        echo "UPDATE the translation file: node /app/autotranslate.js -i ${INPUTTRANSLATIONFILE} -s ${AZURETRANLATIONKEY} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${OUTPUTFILE}"
        if ! node /app/autotranslate.js -i ${INPUTTRANSLATIONFILE} -s ${AZURETRANLATIONKEY} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE} -o ${OUTPUTTRANSLATIONFILE}; then
            echo "RENDER-DETAILS: failed"
            execution_strickness
        else
            echo "RENDER-DETAILS: translation file succesfully updated"
            pretty_print_json ${OUTPUTTRANSLATIONFILE}
        fi
    fi

    # autotranslate the descriptions in the local templates
    pushd ${SLINE}/templates
    FILESTOPROCESS=$(find . -name "*.j2" -exec basename {} .j2 \; )
    for transi in ${FILESTOPROCESS} ; do 
	    echo "process $transi" 
	    node /app/autotranslateJ2.js -i ${transi}.j2 -o ${TLINE}/autotranslation/${transi}_${GOALLANGUAGE}.j2 -s ${AZURETRANLATIONKEY} -m ${PRIMELANGUAGE} -g ${GOALLANGUAGE}
    done
    popd
}

render_rdf() { # SLINE TLINE JSON
    echo "render_rdf: $1 $2 $3 $4 $5 $6 $7"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local DROOT=$5
    local RRLINE=$6
    local LANGUAGE=$7
    local PRIMELANGUAGE=${8-false}

    OUTPUTDIR=${TLINE}/voc
    mkdir -p ${OUTPUTDIR}

    FILENAME=$(jq -r ".name" ${JSONI})
    MERGEDFILENAME=merged_${FILENAME}_${LANGUAGE}.jsonld
    MERGEDFILE=${RLINE}/merged/${MERGEDFILENAME}

    if [ -f ${MERGEDFILE} ]; then
        echo "translations integrated file found"
    else
        echo "defaulting to the primelanguage version"
        MERGEDFILE=${JSONI}
    fi

    COMMANDname=$(echo '.name')
    VOCNAME=$(jq -r "${COMMANDname}" ${MERGEDFILE})

    COMMANDtype=$(echo '.type')
    TYPE=$(jq -r "${COMMANDtype}" ${MERGEDFILE})

    REPORTFILE=${RLINE}/generator-rdf.report

    # XXX TODO create an iterator for each format
    OUTPUT=${OUTPUTDIR}/${VOCNAME}_${LANGUAGE}.ttl
    OUTPUTFORMAT="text/turtle"

    generator_parameters rdfgenerator4 ${JSONI}

    if [ ${TYPE} == "voc" ]; then
        echo "RENDER-DETAILS(rdf): oslo-generator-rdf -s ${TYPE} -i ${MERGEDFILE} -x ${RLINE}/html-nj_${LANGUAGE}.json -r /${DROOT} -t ${TEMPLATELANG} -d ${SLINE}/templates -o ${OUTPUT} -m ${LANGUAGE} -e ${RRLINE}"

        case $TYPE in
        ap)
            SPECTYPE="ApplicationProfile"
            ;;
        voc)
            SPECTYPE="Vocabulary"
            ;;
        oj)
            SPECTYPE="ApplicationProfile"
            ;;
        *)
            echo "ERROR: ${SPECTYPE} not recognized"
            SPECTYPE="ApplicationProfile"
            ;;
        esac

        echo "oslo-generator-rdf for language ${LANGUAGE}" &>>${REPORTFILE}
        echo "-------------------------------------" &>>${REPORTFILE}
        oslo-generator-rdf ${PARAMETERS} \
            --input ${MERGEDFILE} \
            --output ${OUTPUT} \
            --contentType ${OUTPUTFORMAT} \
            --silent false \
            --language ${LANGUAGE} \
            &>>${REPORTFILE}

        if [ ${PRIMELANGUAGE} == true ]; then
            cp ${OUTPUT} ${OUTPUTDIR}/${VOCNAME}.ttl
        fi
        echo "RENDER-DETAILS(RDF): File was rendered in ${OUTPUT}"
    fi

}

render_nunjunks_html() { # SLINE TLINE JSON
    echo "render_html: $1 $2 $3 $4 $5 $6 $7"
    echo "render_html: $1 $2 $3 $4 $5"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local DROOT=$5
    local RRLINE=$6
    local LANGUAGE=$7
    local PRIMELANGUAGE=${8-false}

    FILENAME=$(jq -r ".name" ${JSONI})
    MERGEDFILENAME=merged_${FILENAME}_${LANGUAGE}.jsonld
    MERGEDFILE=${RRLINE}/merged/${MERGEDFILENAME} # XXX This should be the source of the translation merged files

    if [ -f "${MERGEDFILE}" ]; then
        echo "translations integrated file found"
    else
        echo "defaulting to the primelanguage version"
        MERGEDFILE=${JSONI}
    fi

    # step 1: extract all information for a html representation

    mkdir -p ${RLINE}/html
    INT_OUTPUT=${RLINE}/html/int_${FILENAME}_${LANGUAGE}.json
    INT_REPORTFILE=${RLINE}/generator-webuniversum-json.report

    generator_parameters webuniversumgenerator4 ${JSONI}

    echo "oslo-webuniversum-json-generator for language ${LANGUAGE}" &>>${INT_REPORTFILE}
    echo "-------------------------------------" &>>${INT_REPORTFILE}
    oslo-webuniversum-json-generator ${PARAMETERS} \
        --input ${MERGEDFILE} \
        --output ${INT_OUTPUT} \
        --language ${LANGUAGE} \
        &>>${INT_REPORTFILE}

    # step 2: create the html

    generator_parameters htmlgenerator4 ${JSONI}

    COMMAND=$(echo '.type')
    TYPE=$(jq -r "${COMMAND}" ${JSONI})

    # precendence order: Theme repository > publication repository > tool repository
    # the tool installed templates are located at /usr/local/lib/node_modules/@oslo-flanders/html-generator/lib/templates
    mkdir -p ${RRLINE}/templates
    cp -n ${SLINE}/templates/* ${RRLINE}/templates
    cp -n ${RRLINE}/autotranslation/*.j2 ${RRLINE}/templates
    cp -n ${HOME}/project/templates/* ${RRLINE}/templates
    #cp -n /app/views/* ${SLINE}/templates
    #cp -n ${HOME}/project/templates/icons/* ${SLINE}/templates/icons
    mkdir -p ${RLINE}

    OUTPUT=${TLINE}/index_${LANGUAGE}.html
    COMMANDTEMPLATELANG=$(echo '.translation | .[] | select(.language | contains("'${LANGUAGE}'")) | .template')
    TEMPLATELANG=$(jq -r "${COMMANDTEMPLATELANG}" ${JSONI})
    # in case of autotranslate all translations should exists
    COMMANDTITLELANG=$(echo '.translation | .[] | select(.title | contains("'${LANGUAGE}'")) | .template')
    TITLELANG=$(jq -r "${COMMANDTITLELANG}" ${JSONI})

    REPORTFILE=${RLINE}/generator-html.report
    case $TYPE in
    ap)
        SPECTYPE="ApplicationProfile"
        ;;
    voc)
        SPECTYPE="Vocabulary"
        ;;
    oj)
        SPECTYPE="ApplicationProfile"
        ;;
    *)
        echo "ERROR: ${SPECTYPE} not recognized"
        SPECTYPE="ApplicationProfile"
        ;;
    esac

    METADATA=${RRLINE}/html/meta_${FILENAME}.json
    STAKEHOLDERS=${RRLINE}/stakeholders.json

    oslo-generator-html ${PARAMETERS} \
        --input ${INT_OUTPUT} \
        --output ${OUTPUT} \
        --stakeholders ${STAKEHOLDERS} \
        --metadata ${METADATA} \
        --specificationType ${SPECTYPE} \
        --specificationName "Dummy Title" \
        --templates ${RRLINE}/templates \
        --rootTemplate ${TEMPLATELANG} \
        --silent false \
        --language ${LANGUAGE} \
        &>>${REPORTFILE}

    #	oslo-generator-html --input ./webuniversum-config.json --language nl --stakeholders ./stakeholders.json --metadata ./metadata.json --specificationName "OSLO-verkeersmetingen" --specificationType Vocabulary --templates ./templates --rootTemplate vrachtwagenParkeren-voc.njk

    #    if ! node /app/html-generator2.js -s ${TYPE} -i ${MERGEDJSONLD} -x ${RLINE}/html-nj_${LANGUAGE}.json -r /${DROOT} -t ${TEMPLATELANG} -d ${SLINE}/templates -o ${OUTPUT} -m ${LANGUAGE} -e ${RRLINE}; then
    #        echo "RENDER-DETAILS(language html): rendering failed"
    #   execution_strickness
    #    else
    if [ ${PRIMELANGUAGE} == true ]; then
        cp ${OUTPUT} ${TLINE}/index.html
    fi
    echo "RENDER-DETAILS(language html): File was rendered in ${OUTPUT}"
    #    fi

    #    pretty_print_json ${RLINE}/html-nj_${LANGUAGE}.json
}

render_respec_html() { # SLINE TLINE JSON
    echo "render_html: $1 $2 $3 $4 $5 $6 $7"
    echo "render_html: $1 $2 $3 $4 $5"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local DROOT=$5
    local RRLINE=$6
    local LANGUAGE=$7
    local PRIMELANGUAGE=${8-false}

    FILENAME=$(jq -r ".name" ${JSONI})
    MERGEDFILENAME=merged_${FILENAME}_${LANGUAGE}.jsonld
    MERGEDFILE=${RRLINE}/merged/${MERGEDFILENAME}

    if [ -f ${MERGEDFILE} ]; then
        echo "translations integrated file found"
    else
        echo "defaulting to the primelanguage version"
        MERGEDFILE=${JSONI}
    fi

    # precendence order: Theme repository > publication repository > tool repository
    # XXX TODO: reactivate
    #cp -n ${HOME}/project/templates/* ${SLINE}/templates
    #cp -n /app/views/* ${SLINE}/templates
    #cp -n ${HOME}/project/templates/icons/* ${SLINE}/templates/icons
    mkdir -p ${RLINE}

    COMMAND=$(echo '.type')
    TYPE=$(jq -r "${COMMAND}" ${JSONI})

    mkdir -p ${TLINE}/html

    OUTPUT=${TLINE}/respec-index_${LANGUAGE}.html
    COMMANDTEMPLATELANG=$(echo '.translation | .[] | select(.language | contains("'${LANGUAGE}'")) | .template')
    TEMPLATELANG=$(jq -r "${COMMANDTEMPLATELANG}" ${JSONI})

    REPORTFILE=${RLINE}/generator-respec.report
    generator_parameters htmlgenerator4 ${JSONI}

    echo "RENDER-DETAILS(language html): node /app/html-generator2.js -s ${TYPE} -i ${MERGEDJSONLD} -x ${RLINE}/html-nj_${LANGUAGE}.json -r /${DROOT} -t ${TEMPLATELANG} -d ${SLINE}/templates -o ${OUTPUT} -m ${LANGUAGE} -e ${RLINE}"

    case $TYPE in
    ap)
        SPECTYPE="ApplicationProfile"
        ;;
    voc)
        SPECTYPE="Vocabulary"
        ;;
    oj)
        SPECTYPE="ApplicationProfile"
        ;;
    *)
        echo "ERROR: ${SPECTYPE} not recognized"
        SPECTYPE="ApplicationProfile"
        ;;
    esac

    echo "oslo-generator-respec for language ${LANGUAGE}" &>>${REPORTFILE}
    echo "-------------------------------------" &>>${REPORTFILE}
    oslo-generator-respec ${PARAMETERS} \
        --input ${MERGEDFILE} \
        --output ${OUTPUT} \
        --specificationType ${SPECTYPE} \
        --specificationName "Dummy Title" \
        --silent false \
        --language ${LANGUAGE} \
        &>>${REPORTFILE}

    #    if ! node /app/html-generator2.js -s ${TYPE} -i ${MERGEDJSONLD} -x ${RLINE}/html-nj_${LANGUAGE}.json -r /${DROOT} -t ${TEMPLATELANG} -d ${SLINE}/templates -o ${OUTPUT} -m ${LANGUAGE} -e ${RRLINE}; then
    #        echo "RENDER-DETAILS(language html): rendering failed"
    #   execution_strickness
    #    else
    #   There might be a parameter to make this a active, but for now respec is considered not as the main output
    #   if [ ${PRIMELANGUAGE} == true ] ; then
    #      cp ${OUTPUT} ${TLINE}/index.html
    #   fi
    #        echo "RENDER-DETAILS(language html): File was rendered in ${OUTPUT}"
    #    fi

    #    pretty_print_json ${RLINE}/html-nj_${LANGUAGE}.json
}

link_html() { # SLINE TLINE JSON
    echo "link_html: $1 $2 $3 $4 $5 $6 $7"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local DROOT=$5
    local RRLINE=$6
    local LANGUAGE=$7

}

function pretty_print_json() {
    # echo "pretty_print_json: $1"
    if [ -f "$1" ]; then
        jq . $1 >/tmp/pp.json
        mv /tmp/pp.json $1
    fi
}

render_example_template() { # SLINE TLINE JSON
    echo "render_example_template: $1 $2 $3 $4 $5 $6 $7"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local DROOT=$5
    local RRLINE=$6
    local LANGUAGE=$7

    echo "XXX TODO This option is not yet implemented as a solution in version 4"

    FILENAME=$(jq -r ".name" ${JSONI})
    MERGEDFILENAME=merged_${FILENAME}_${LANGUAGE}.jsonld
    MERGEDFILE=${RLINE}/merged/${MERGEDFILENAME}

    if [ -f ${MERGEDFILE} ]; then
        echo "translations integrated file found"
    else
        echo "defaulting to the primelanguage version"
        MERGEDFILE=${JSONI}
    fi

    OUTPUT=${TLINE}/examples/
    mkdir -p ${OUTPUT}
    mkdir -p ${OUTPUT}/context
    touch ${OUTPUT}/.gitignore

    COMMAND=$(echo '.examples')
    EXAMPLE=$(jq -r "${COMMAND}" ${MERGEDFILE})
    echo "example " ${EXAMPLE}
    if [ "${EXAMPLE}" == true ]; then
        echo "no generator execution defined"
        #        echo "RENDER-DETAILS(example generator): node /app/exampletemplate-generator2.js -i ${MERGEDJSONLD} -o ${OUTPUT} -l ${LANGUAGE} -h /doc/${TYPE}/${BASENAME}"
        #        if ! node /app/exampletemplate-generator2.js -i ${MERGEDJSONLD} -o ${OUTPUT} -l ${LANGUAGE} -h /doc/${TYPE}/${BASENAME}; then
        #            echo "RENDER-DETAILS(example generator): rendering failed"
        #            execution_strickness
        #        else
        #            echo "RENDER-DETAILS(example generator): Files were rendered in ${OUTPUT}"
        #        fi
    fi
}

touch2() { mkdir -p "$(dirname "$1")" && touch "$1"; }

prettyprint_jsonld() {
    local FILE=$1

    if [ -f ${FILE} ]; then
        touch2 /tmp/pp/${FILE}
        jq --sort-keys . ${FILE} >/tmp/pp/${FILE}
        cp /tmp/pp/${FILE} ${FILE}
    fi
}

render_context() { # SLINE TLINE JSON
    echo "render_context: $1 $2 $3 $4 $5"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local GOALLANGUAGE=$5
    local PRIMELANGUAGE=${6-false}

    FILENAME=$(jq -r ".name" ${JSONI})
    OUTFILE=${FILENAME}.jsonld
    OUTFILELANGUAGE=${FILENAME}_${GOALLANGUAGE}.jsonld

    MERGEDFILENAME=merged_${FILENAME}_${GOALLANGUAGE}.jsonld
    MERGEDFILE=${SLINE}/merged/${MERGEDFILENAME}

    if [ -f ${MERGEDFILE} ]; then
        echo "translations integrated file found"
    else
        echo "defaulting to the primelanguage version"
        MERGEDFILE=${JSONI}
    fi

    REPORTFILE=${RLINE}/generator-jsonld-context.report
    mkdir -p ${RLINE}

    COMMAND=$(echo '.type')
    TYPE=$(jq -r "${COMMAND}" ${JSONI})

    generator_parameters contextgenerator4 ${JSONI}

    if [ ${TYPE} == "ap" ] || [ ${TYPE} == "oj" ]; then
        #        echo "RENDER-DETAILS(context): node /app/json-ld-generator.js -d -l label -i ${JSONI} -o ${TLINE}/context/${OUTFILELANGUAGE} "
        mkdir -p ${TLINE}/context

        echo "oslo-jsonld-context-generator for language ${GOALLANGUAGE}" &>>${REPORTFILE}
        echo "-------------------------------------" &>>${REPORTFILE}
        oslo-jsonld-context-generator ${PARAMETERS} \
            --input ${MERGEDFILE} \
            --language ${GOALLANGUAGE} \
            --output ${TLINE}/context/${OUTFILELANGUAGE} \
            &>>${REPORTFILE}

        #        echo "RENDER-DETAILS(context-language-aware): node /app/json-ld-generator2.js -d -l label -i ${MERGEDJSONLD} -o ${TLINE}/context/${OUTFILELANGUAGE} -m ${GOALLANGUAGE}"
        #        if ! node /app/json-ld-generator2.js -d -l label -i ${MERGEDJSONLD} -o ${TLINE}/context/${OUTFILELANGUAGE} -m ${GOALLANGUAGE}; then
        #            echo "RENDER-DETAILS(context-language-aware): See XXX for more details, Rendering failed"
        #            execution_strickness
        #        else
        #            echo "RENDER-DETAILS(context-language-aware): Rendering successfull, File saved to  ${TLINE}/context/${OUTFILELANGUAGE}"
        #        fi

        prettyprint_jsonld ${TLINE}/context/${OUTFILELANGUAGE}
        if [ ${PRIMELANGUAGE} == true ]; then
            cp ${TLINE}/context/${OUTFILELANGUAGE} ${TLINE}/context/${OUTFILE}
        fi
    fi
}

render_shacl_languageaware() {
    echo "render_shacl: $1 $2 $3 $4 $5"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local LINE=$5
    local GOALLANGUAGE=$6
    local PRIMELANGUAGE=${7-false}

    FILENAME=$(jq -r ".name" ${JSONI})

    MERGEDFILENAME=merged_${FILENAME}_${GOALLANGUAGE}.jsonld
    MERGEDFILE=${SLINE}/merged/${MERGEDFILENAME}

    if [ -f ${MERGEDFILE} ]; then
        echo "translations integrated file found"
    else
        echo "defaulting to the primelanguage version"
        MERGEDFILE=${JSONI}
    fi

    OUTFILE=${TLINE}/shacl/${FILENAME}-SHACL_${GOALLANGUAGE}.jsonld
    OUTREPORT=${RLINE}/shacl/${FILENAME}-SHACL_${GOALLANGUAGE}.report

    REPORTFILE=${RLINE}/generator-shacl.report

    COMMAND=$(echo '.type')
    TYPE=$(jq -r "${COMMAND}" ${JSONI})

    generator_parameters shaclgenerator4 ${JSONI}

    if [ ${TYPE} == "ap" ] || [ ${TYPE} == "oj" ]; then
        DOMAIN="${HOSTNAME}/${LINE}"
        #        echo "RENDER-DETAILS(shacl-languageaware): node /app/shacl-generator.js -i ${MERGEDJSONLD} ${PARAMETERS} -d ${DOMAIN} -p ${DOMAIN} -o ${OUTFILE} -l ${GOALLANGUAGE}"
        mkdir -p ${TLINE}/shacl
        mkdir -p ${RLINE}/shacl

        echo "oslo-shacl-template-generator for language ${GOALLANGUAGE}" &>>${REPORTFILE}
        echo "-------------------------------------" &>>${REPORTFILE}
        oslo-shacl-template-generator ${PARAMETERS} \
            --input ${MERGEDFILE} \
            --language ${GOALLANGUAGE} \
            --output ${OUTFILE} \
            --shapeBaseURI ${DOMAIN} \
            --applicationProfileURL ${DOMAIN} \
            &>>${REPORTFILE}

        #        if ! node /app/shacl-generator2.js -i ${MERGEDJSONLD} ${PARAMETERS} -d ${DOMAIN} -p ${DOMAIN} -o ${OUTFILE} -l ${GOALLANGUAGE} 2>&1 | tee ${OUTREPORT}; then
        #            echo "RENDER-DETAILS(shacl-languageaware): See ${OUTREPORT} for the details"
        #            execution_strickness
        #        else
        #            echo "RENDER-DETAILS(shacl-languageaware): saved to ${OUTFILE}"
        #        fi
        prettyprint_jsonld ${OUTFILE}
        if [ ${PRIMELANGUAGE} == true ]; then
            cp ${OUTFILE} ${TLINE}/shacl/${FILENAME}-SHACL.jsonld
        fi
    fi
    #    fi
}

render_xsd() { # SLINE TLINE JSON
    echo "render_xsd: $1 $2 $3 $4 $5"
    local SLINE=$1
    local TLINE=$2
    local JSONI=$3
    local RLINE=$4
    local GOALLANGUAGE=$5
    local PRIMELANGUAGE=${6-false}

    echo "XXX TODO This option is not yet implemented as a solution in version 4"

    FILENAME=$(jq -r ".name" ${JSONI})
    MERGEDFILENAME=merged_${FILENAME}_${GOALLANGUAGE}.jsonld
    MERGEDFILE=${RLINE}/merged/${MERGEDFILENAME}

    if [ -f ${MERGEDFILE} ]; then
        echo "translations integrated file found"
    else
        echo "defaulting to the primelanguage version"
        MERGEDFILE=${JSONI}
    fi

    OUTFILE=${FILENAME}.xsd
    OUTFILELANGUAGE=${FILENAME}_${GOALLANGUAGE}.xsd

    mkdir -p ${TLINE}/xsd
    touch ${TLINE}/xsd/.gitignore

    COMMAND=$(echo '.type')
    TYPE=$(jq -r "${COMMAND}" ${JSONI})

    #    XSDDOMAIN="https://data.europa.eu/m8g/xml/"

    if [ ${TYPE} == "ap" ] || [ ${TYPE} == "oj" ]; then

        #        echo "RENDER-DETAILS(xsd): node /app/xsd-generator.js -d -l label -i ${MERGEDJSONLD} -o ${TLINE}/xsd/${OUTFILELANGUAGE} -m ${GOALLANGUAGE} -b ${XSDDOMAIN}"
        #        if ! node /app/xsd-generator.js -d -l label -i ${MERGEDJSONLD} -o ${TLINE}/xsd/${OUTFILELANGUAGE} -m ${GOALLANGUAGE} -b ${XSDDOMAIN}; then
        #            echo "RENDER-DETAILS(xsd): See XXX for more details, Rendering failed"
        #            execution_strickness
        #        else
        #            echo "RENDER-DETAILS(xsd): Rendering successfull, File saved to  ${TLINE}/xsd/${OUTFILELANGUAGE}"
        #        fi

        if [ ${PRIMELANGUAGE} == true ]; then
            cp ${TLINE}/xsd/${OUTFILELANGUAGE} ${TLINE}/xsd/${OUTFILE}
        fi

    fi
}

echo "render-details: starting with $1 $2 $3"

cat ${CHECKOUTFILE} | while read line; do
    SLINE=${TARGETDIR}/src/${line}
    TLINE=${TARGETDIR}/report4/${line}
    RLINE=${TARGETDIR}/report4/${line}
    TRLINE=${TARGETDIR}/translation/${line}
    echo "RENDER-DETAILS: Processing line ${SLINE} => ${TLINE},${RLINE}"
    #
    # TODO: the extract-what-4.sh writes the derived output in TLINE/RLINE
    # In 3.0 version this was in the SLINE
    # Therefore the next test should be considered in redesign of extract-what-4
    if [ -d "${RLINE}" ]; then
        for i in ${RLINE}/all-*.jsonld; do
            echo "RENDER-DETAILS: convert $i using ${DETAILS}"
            case ${DETAILS} in
            html)
                TLINE=${TARGETDIR}/target/${line}
                RLINE=${TARGETDIR}/report4/html/${line}
		mkdir -p ${TLINE}
		mkdir -p ${RLINE}
                render_nunjunks_html $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report4/${line} ${PRIMELANGUAGE} true
                for g in ${GOALLANGUAGE}; do
                    generate_for_language ${g} ${i}
                    if [ ${GENERATEDARTEFACT} == true ]; then
                        render_nunjunks_html $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report4/${line} ${g}
                    fi
                done
                ;;
            respec)
                TLINE=${TARGETDIR}/target/${line}
                RLINE=${TARGETDIR}/report4/respec/${line}
		mkdir -p ${TLINE}
		mkdir -p ${RLINE}
                render_respec_html $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report4/${line} ${PRIMELANGUAGE} true
                for g in ${GOALLANGUAGE}; do
                    generate_for_language ${g} ${i}
                    if [ ${GENERATEDARTEFACT} == true ]; then
                        render_respec_html $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report4/${line} ${g}
                    fi
                done
                ;;
            rdf)
                TLINE=${TARGETDIR}/target/${line}
                RLINE=${TARGETDIR}/report4/rdf/${line}
		mkdir -p ${TLINE}
		mkdir -p ${RLINE}
                render_rdf $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report4/${line} ${PRIMELANGUAGE} true
                for g in ${GOALLANGUAGE}; do
                    generate_for_language ${g} ${i}
                    if [ ${GENERATEDARTEFACT} == true ]; then
                        render_rdf $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report4/${line} ${g}
                    fi
                done
                ;;
            shacl)
		   # the source for the shacl generator is solely the intermediate json
                SLINE=${TARGETDIR}/report4/${line}
                TLINE=${TARGETDIR}/target/${line}
                RLINE=${TARGETDIR}/report4/shacl/${line}
		mkdir -p ${TLINE}
		mkdir -p ${RLINE}
                render_shacl_languageaware $SLINE $TLINE $i $RLINE ${TARGETDIR}/report4/${line} ${PRIMELANGUAGE} true
                for g in ${GOALLANGUAGE}; do
                    generate_for_language ${g} ${i}
                    if [ ${GENERATEDARTEFACT} == true ]; then
                        render_shacl_languageaware $SLINE $TLINE $i $RLINE ${TARGETDIR}/report4/${line} ${g}
                    fi
                done
                ;;
            context)
		   # the source for the context generator is solely the intermediate json
                SLINE=${TARGETDIR}/report4/${line}
                TLINE=${TARGETDIR}/target/${line}
                RLINE=${TARGETDIR}/report4/context/${line}
		mkdir -p ${TLINE}
		mkdir -p ${RLINE}
                render_context $SLINE $TLINE $i $RLINE ${PRIMELANGUAGE} true
                for g in ${GOALLANGUAGE}; do
                    generate_for_language ${g} ${i}
                    if [ ${GENERATEDARTEFACT} == true ]; then
                        render_context $SLINE $TLINE $i $RLINE ${g}
                    fi
                done
                ;;
            xsd)
                render_xsd $SLINE $TLINE $i $RLINE ${PRIMELANGUAGE} true
                for g in ${GOALLANGUAGE}; do
                    generate_for_language ${g} ${i}
                    if [ ${GENERATEDARTEFACT} == true ]; then
                        render_xsd $SLINE $TLINE $i $RLINE ${g}
                    fi
                done
                ;;
            metadata)
                render_metadata ${PRIMELANGUAGE} $i ${line} ${SLINE} ${TLINE}
                for g in ${GOALLANGUAGE}; do
                    render_metadata ${g} $i ${line} ${SLINE} ${TLINE}
                done
                ;;
            translation)
                render_translationfiles ${PRIMELANGUAGE} ${PRIMELANGUAGE} $i ${SLINE} ${TLINE}
                for g in ${GOALLANGUAGE}; do
                    render_translationfiles ${PRIMELANGUAGE} ${g} $i ${SLINE} ${TLINE}
                done
                ;;
            autotranslate)
                AUTOTRANSLATE=$(jq -r .toolchain.autotranslate ${CONFIGDIR}/config.json)
    		if [ ${AUTOTRANSLATE} == true ]; then
                for g in ${GOALLANGUAGE}; do
                    autotranslatefiles ${PRIMELANGUAGE} ${g} $i ${SLINE} ${TLINE}
                done
		fi
                ;;
            merge)
                render_merged_files ${PRIMELANGUAGE} ${PRIMELANGUAGE} $i ${SLINE} ${TRLINE} ${RLINE}
                for g in ${GOALLANGUAGE}; do
                    render_merged_files ${PRIMELANGUAGE} ${g} $i ${SLINE} ${TRLINE} ${RLINE}
                done
                ;;
            example)
                render_example_template $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report/${line} ${PRIMELANGUAGE}
                for g in ${GOALLANGUAGE}; do
                    generate_for_language ${g} ${i}
                    if [ ${GENERATEDARTEFACT} == true ]; then
                        render_example_template $SLINE $TLINE $i $RLINE ${line} ${TARGETDIR}/report/${line} ${g}
                    fi
                done
                ;;
            *) echo "RENDER-DETAILS: ${DETAILS} not handled yet" ;;
            esac
        done
    else
        echo "Error: ${SLINE}"
    fi
done
