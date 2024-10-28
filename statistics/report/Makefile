TARGETDIR:=/tmp/workspace/stats


ALLSPECIFICATIONS=$(shell find . -name *.jsonld  | grep all- )
STATSPERSPECIFICATIONS=$(patsubst %.jsonld,${TARGETDIR}/%.stat,${ALLSPECIFICATIONS})
CLEANSTATSPERSPECIFICATIONS=$(patsubst %.jsonld,${TARGETDIR}/%.stat.*,${ALLSPECIFICATIONS})

rootspecifications: publication.json
	node /app/publicationpoints.js -p "#||#" -i $< -o ${TARGETDIR}/navigation.json
	node /app/publicationpoints.js -p "#||#" -i $< -o /tmp/rootpublicationpoints.json --rootsonly
	jq '.[]' /tmp/rootpublicationpoints.json > /tmp/rootpublicationpoints.1.json
	sed -i 's/"//g' /tmp/rootpublicationpoints.1.json
	cp /tmp/rootpublicationpoints.1.json $@
	cp $@ ${TARGETDIR}/$@

ROOTSPECIFICATIONS=$(shell cat rootspecifications)


.PHONY: allstats
allstats: ${STATSPERSPECIFICATIONS}

#	./calc_stat.sh $< ${TARGETDIR}/$(dir $@) $(notdir $@)

${TARGETDIR}/%.stat : %.jsonld
	./calc_stat.sh $< $(dir $@) $(notdir $@)

.PHONY: aggr.organisations
aggr.organisations: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.organisations  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.organisations
root.organisations: ${STATSPERSPECIFICATIONS}
	echo "[]" > $@
	for file in $^ ; \
        do \
                ./calc_support.sh $${file} $@ organisations ;\
        done
	cp $@ ${TARGETDIR}/$@


.PHONY: aggr.authors
aggr.authors: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.authors  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.authors
root.authors: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} $@ authors ;\
	 done 
	 cp $@ ${TARGETDIR}/$@

.PHONY: aggr.editors
aggr.editors: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.editors  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.editors
root.editors: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} $@ editors ;\
	 done 
	 cp $@ ${TARGETDIR}/$@

.PHONY: aggr.contributors
aggr.contributors: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.contributors  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.contributors
root.contributors: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} $@ contributors ;\
	 done 
	 cp $@ ${TARGETDIR}/$@


.PHONY: aggr.class
aggr.class: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.classes  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.class
root.class: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} $@ classes ;\
	 done 
	 cp $@ ${TARGETDIR}/$@
root.class.voc root.class.ap: ${STATSPERSPECIFICATIONS}
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} root.class classes true true ;\
	 done 
	 cp root.class.* ${TARGETDIR}

.PHONY: aggr.props
aggr.props: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.properties  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.props
root.props: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} $@ properties ;\
	 done 
	 cp $@ ${TARGETDIR}/$@
root.props.voc root.props.ap: ${STATSPERSPECIFICATIONS}
	 echo "[]" > root.props.voc
	 echo "[]" > root.props.ap
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} root.props properties true true;\
	 done 
	 cp root.props.* ${TARGETDIR}

.PHONY: aggr.extclass
aggr.extclass: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.externalclasses  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.extclass
root.extclass: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} $@ externalclasses ;\
	 done 
	 cp $@ ${TARGETDIR}/$@
root.extclass.%: ${STATSPERSPECIFICATIONS}
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} root.extclass externalclasses true true;\
	 done 
	 cp root.extclass.* ${TARGETDIR}

.PHONY: aggr.extprops
aggr.extprops: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.externalproperties  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@

.PHONY: root.extprops
root.extprops: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} $@ externalproperties ;\
	 done 
	 cp $@ ${TARGETDIR}/$@
root.extprops.%: ${STATSPERSPECIFICATIONS}
	 for file in $^ ; \
		do \
                ./calc_support.sh $${file} root.extprops externalproperties true true;\
	 done 
	 cp root.extprops.* ${TARGETDIR}

.PHONY: aggr.specstats
aggr.specstats: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		if [ -s $${file} ] ; then \
			jq  'del(.values) ' "$${file}" > /tmp/spec ;\
			jq -s '.[0] + [ .[1] ] ' $@ "/tmp/spec" >> $@.0 ;\
			mv $@.0 $@;\
		fi\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: root.specstats
root.specstats: aggr.specstats
	cp aggr.specstats root.specstats
	# XXX TODO create a version for only the root specifications, for now all specs are included in this one

aggr.stat: aggr.organisations aggr.class aggr.props aggr.extclass aggr.extprops aggr.authors aggr.editors aggr.contributors aggr.specstats
	./calc_aggr.sh aggr ${TARGETDIR}/$@


%.voc.csv: %.voc
	jq '.[] |= {"spec": .spec, "label" : .label[0]."@value", "assignedURI": .assignedURI } ' $^ > /tmp/$@
	jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' /tmp/$@ > ${TARGETDIR}/$@
%.ap.csv: %.ap
	jq '.[] |= {"spec": .spec, "label" : .label[0]."@value", "assignedURI": .assignedURI } ' $^ > /tmp/$@
	jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' /tmp/$@ > ${TARGETDIR}/$@

ROOTS=root.classes root.properties root.externalclasses root.externalproperties
ROOTSVOC=$(patsubst %, %.voc,${ROOTS})
ROOTSAP=$(patsubst %, %.ap,${ROOTS})
ROOTSNAMED=${ROOTSVOC}
ROOTSNAMED+=${ROOTSAP}
CSVNAMED=$(patsubst %,%.csv,${ROOTSNAMED})

${ROOTSNAMED}: ${STATSPERSPECIFICATIONS}
	for rrootfile in ${ROOTSNAMED} ; \
		do \
		echo "[]" > $${rrootfile} ; \
	 done
	baseroot=${$@%.*};
	query=${baseroot##*.};
	echo $${query}
	for file in $^ ; \
		do \
                ./calc_support.sh $${file} $${baseroot} queries true true;\
	 done 
	cp $${baseroot}.* ${TARGETDIR}

rootnamed.stat: ${ROOTSNAMED}
	touch rootnamed.stat
csv.stat: ${CSVNAMED}
	touch csv.stat

root.stat: root.organisations root.class root.props root.extclass root.extprops root.authors root.editors root.contributors root.specstats rootnamed.stat
	./calc_aggr.sh root ${TARGETDIR}/$@



finalize:
	for file in "${CLEANSTATSPERSPECIFICATIONS}" ; \
		do \
		rm $${file} ;\
	 done 

print:
	echo "${CLEANSTATSPERSPECIFICATIONS}" > L
	echo "${STATSPERSPECIFICATIONS}" > LL

clean: 
	rm -rf ${STATSPERSPECIFICATIONS} 
	for file in "${CLEANSTATSPERSPECIFICATIONS}" ; \
		do \
		rm $${file} ;\
	 done 
