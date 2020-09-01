#set-up for single machine or cluster based execution
. ./cmd.sh
#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh


echo ============================================================================
echo "          Preparing Data Files for Language Modeling  	        "
echo ============================================================================

for folder in train test
do

#The function is to extract the utterance id
realpath ./raw/text/$folder/*.lab | xargs -l basename -s .lab > ./data/$folder/textutt

echo "Creating the list of transcripts"
paste -d '\n' ./raw/text/$folder/*.lab > ./data/$folder/trans

echo "Creating the text file of uttid mapped to transcript"
paste ./data/$folder/textutt ./data/$folder/trans > ./data/$folder/text

done

echo "Creating LM model creation input file"
while read line
do
echo "<s> $line </s>" >> ./data/train/lm_train.txt
done <./data/train/trans


echo ============================================================================
echo "                  Preparing the Lexicon Dictionary       	        "
echo ============================================================================

mkdir -p data/local/dict

echo "Creating the sorted lexicon file"
sort ./raw/language/lexicon.txt | paste > ./data/local/dict/lexicon.txt 

echo "Creating the list of Phones"
cat ./data/local/dict/lexicon.txt | cut -d '	' -f 2  - | tr ' ' '\n' | sort | uniq > ./data/local/dict/phones.txt 

cat ./data/local/dict/phones.txt | sed /sil/d > ./data/local/dict/nonsilence_phones.txt 

echo "sil" > ./data/local/dict/silence_phones.txt 
echo "sil" > ./data/local/dict/optional_silence.txt 


touch ./data/local/dict/extra_phones.txt ./data/local/dict/extra_questions.txt



echo ============================================================================
echo "                  Preparing the Language Model Files    	        "
echo ============================================================================

kaldi_root_dir='../..'
#kaldi_root_dir='/home/kavya/kavyadev/kaldi'
basepath='.'

ls $kaldi_root_dir
ls $basepath

lm_arpa_path=$basepath/data/local/lm

train_dict=dict
train_lang=lang_bigram
train_folder=train

n_gram=2 # This specifies bigram or trigram. for bigram set n_gram=2 for tri_gram set n_gram=3

echo ============================================================================
echo "                   Creating  n-gram LM               	        "
echo ============================================================================

rm -rf $basepath/data/local/$train_dict/lexiconp.txt $basepath/data/local/$train_lang $basepath/data/local/tmp_$train_lang $basepath/data/$train_lang
mkdir $basepath/data/local/tmp_$train_lang

utils/prepare_lang.sh --num-sil-states 3 data/local/$train_dict '!sil' data/local/$train_lang data/$train_lang

$kaldi_root_dir/tools/irstlm/bin/build-lm.sh -i $basepath/data/$train_folder/lm_train.txt -n $n_gram -o $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz

gunzip -c $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz | utils/find_arpa_oovs.pl data/$train_lang/words.txt  > data/local/tmp_$train_lang/oov.txt

gunzip -c $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz | grep -v '<s> <s>' | grep -v '<s> </s>' | grep -v '</s> </s>' | grep -v 'SIL' | $kaldi_root_dir/src/lmbin/arpa2fst - | fstprint | utils/remove_oovs.pl data/local/tmp_$train_lang/oov.txt | utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/$train_lang/words.txt --osymbols=data/$train_lang/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon > data/$train_lang/G.fst 
$kaldi_root_dir/src/fstbin/fstisstochastic data/$train_lang/G.fst 



echo ============================================================================
echo "                   End of Script             	        "
echo ============================================================================
