grep "^AL" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/AL.csv
grep "^B" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/B.csv
grep "^C" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/C.csv
grep "^D" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/D.csv
grep "^E" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/E.csv
