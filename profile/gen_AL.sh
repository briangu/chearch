grep "^AL" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/AL.csv
grep "^B,2" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/B.csv
grep "^C,4" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/C.csv
grep "^D,2" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/D.csv
grep "^E,4" $1 | cut -f 3 -d ',' | python ../find_min.py $1 >> ../out/E.csv
