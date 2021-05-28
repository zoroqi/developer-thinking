echo "# 杂七杂八技术上的思考" > README.md; echo "" >> README.md; for i in `find . -name '*.md' | sort -n `; do name=`head -1 $i`; echo "* [$name]($i)" >> README.md;done
