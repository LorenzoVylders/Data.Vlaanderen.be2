TARGETDIR:=/tmp/workspace/stats

SPECIFICATIONS=$(shell find . -name *.jsonld  | grep all- )
STATSPERSPECIFICATIONS=$(patsubst %.jsonld,${TARGETDIR}/%.stat,${SPECIFICATIONS})
CLEANSTATSPERSPECIFICATIONS=$(patsubst %.jsonld,${TARGETDIR}/%.stat.*,${SPECIFICATIONS})


.PHONY: allstats
allstats: ${STATSPERSPECIFICATIONS}

#	./calc_stat.sh $< ${TARGETDIR}/$(dir $@) $(notdir $@)

${TARGETDIR}/%.stat : %.jsonld
	./calc_stat.sh $< $(dir $@) $(notdir $@)

.PHONY: aggr.organisations
aggr.organisations: ${STATSPERSPECIFICATIONS}
	 echo "[]" > aggr.organisations
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.organisations  ' aggr "$${file}" >> aggr.organisations.0 ;\
		mv aggr.organisations.0 aggr.organisations ;\
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
.PHONY: aggr.editors
aggr.editors: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.editors  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
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
.PHONY: aggr.class
aggr.class: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.classes  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: aggr.props
aggr.props: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.properties  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: aggr.extclass
aggr.extclass: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.externalclasses  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: aggr.extprops
aggr.extprops: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq -s '.[0] + .[1].values.externalproperties  ' $@ "$${file}" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@
.PHONY: aggr.specstats
aggr.specstats: ${STATSPERSPECIFICATIONS}
	 echo "[]" > $@
	 for file in $^ ; \
		do \
		jq  'del(.values) ' "$${file}" > /tmp/spec ;\
		jq -s '.[0] + [ .[1] ] ' $@ "/tmp/spec" >> $@.0 ;\
		mv $@.0 $@;\
	 done 
	 cp $@ ${TARGETDIR}/$@

aggr.stat: aggr.organisations aggr.class aggr.props aggr.extclass aggr.extprops aggr.authors aggr.editors aggr.contributors aggr.specstats
	./calc_aggr.sh aggr ${TARGETDIR}/$@


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
