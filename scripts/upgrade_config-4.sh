#!/bin/bash

TARGETDIR=$1
CONFIGDIR=$2
CHECKOUTFILE=${TARGETDIR}/checkouts.txt

#
# convert older toolchain version configs to this version
#

upgrade_config() {
    local SLINE=$1
    echo "upgrade config for $SLINE"

    PRIMELANGUAGE=$(jq -r ".primeLanguage" ${CONFIGDIR}/config.json)

    echo "prime language is $PRIMELANGUAGE"

    HASTRANSLATION=$(jq -r .[0].translation[0].language ${SLINE}/.names.json)
    echo "${HASTRANSLATION}: if null then no translation is present and thus configuration will be updated."

    TITLE=$(jq -r .[0].title ${SLINE}/.names.json)
    TEMPLATE=$(jq -r .[0].template ${SLINE}/.names.json)
    NAME=$(jq -r .[0].name ${SLINE}/.names.json)

    echo "title: $TITLE"
    echo "template: $TEMPLATE"
    echo "name: $NAME"

    TRANSLATIONOBJTEMPLATE='{"translation" : [{
       "language" : $jqlanguage,
       "title" : $jqtitle,
       "template" : $jqtemplate,
       "translationjson" : $jqtranslation,
       "mergefile" : $jqmergefile
     }]}'

    JQTRANSLATION="${NAME}_${PRIMELANGUAGE}.json"

    TRANSLATIONOBJ=$(jq -n \
        --arg jqlanguage "${PRIMELANGUAGE}" --arg jqtitle "${TITLE}" --arg jqtemplate ${TEMPLATE} \
        --arg jqtranslation $JQTRANSLATION --arg jqmergefile ${NAME}_${PRIMELANGUAGE}_merged.json \
        "${TRANSLATIONOBJTEMPLATE}")
    echo $TRANSLATIONOBJ >/tmp/upgrade.json

    # check for the amount of items in the .names.json
    AMOUNT=$(jq length ${SLINE}/.names.json)

    echo "amount of items in the .names.json: $AMOUNT"

    if [ ${AMOUNT} -eq 1 ]; then

        if [ "$HASTRANSLATION" == "" ] || [ "$HASTRANSLATION" == "null" ]; then

            jq -s '[.[0][0] * .[1]]' ${SLINE}/.names.json /tmp/upgrade.json >/tmp/mergedupgrade.json
            cp /tmp/mergedupgrade.json ${SLINE}/.names.json
        fi

    else
        echo "ERROR only a list with a single matching value should be in the specification config"
        cat ${SLINE}/.names.json
        exit -1
    fi

}

echo "upgrade config: starting with $TARGETDIR $CONFIGDIR"

cat ${CHECKOUTFILE} | while read line; do
    SLINE=${TARGETDIR}/src/${line}
    TLINE=${TARGETDIR}/target/${line}
    RLINE=${TARGETDIR}/report/${line}
    TRLINE=${TARGETDIR}/translation/${line}
    if [ -d "${SLINE}" ]; then
        upgrade_config ${SLINE}
    else
        echo "Error: ${SLINE}"
    fi
done