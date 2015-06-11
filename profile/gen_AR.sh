grep "^AR" $1 | tr " " "," | cut -f 4- -d ',' | python ../find_min.py $1 >> ../out/AR.csv
