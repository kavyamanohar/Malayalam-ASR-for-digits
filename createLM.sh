#set-up for single machine or cluster based execution
. ./cmd.sh
#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh


echo ============================================================================
echo "          Preparing Data Files for Language Modeling  	        "
echo ============================================================================

#The function is to extract the utterance id
realpath ./raw/text/train/*.lab | xargs -l basename -s .lab > ./data/train/textutt

echo "Creating the list of transcripts"
paste -d '\n' ./raw/text/train/*.lab > ./data/train/trans

echo "Creating the text file of uttid mapped to transcript"
paste ./data/train/textutt ./data/train/trans > ./data/train/text


echo "Creating LM model creation input file"
while read line
do
echo "<s> $line </s>" >> ./data/train/lm_train.txt
done <./data/train/trans


echo ============================================================================
echo "                  Preparing the Language Dictionary       	        "
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

#kaldi_root_dir='../..'
kaldi_root_dir='/home/kavya/kavyadev/kaldi'
basepath='.'


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



# echo "===== MONO TRAINING ====="
# echo

# nj=1
# steps/train_mono.sh --nj $nj --cmd "$train_cmd"  data/train data/$train_lang exp/mono  || exit 1


# echo
# echo "===== MONO DECODING ====="
# echo
# utils/mkgraph.sh --mono data/$train_lang exp/mono exp/mono/graph || exit 1
# steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode



# echo
# echo "===== MONO ALIGNMENT ====="
# echo
# steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/$train_lang exp/mono exp/mono_ali || exit 1

# echo
# echo "===== TRI1 (first triphone pass) TRAINING ====="
# echo
# steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/$train_lang exp/mono_ali exp/tri1 || exit 1

# echo "===== TRI1 (first triphone pass) DECODING ====="
# echo
# utils/mkgraph.sh data/$train_lang exp/tri1 exp/tri1/graph || exit 1
# steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode

# echo "===== TRI_LDA (second triphone pass) ALIGNMENT ====="
# echo
# steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri1 exp/tri1_ali

# echo "===== TRI_LDA (second triphone pass) LDA Training ====="
# echo

# steps/train_lda_mllt.sh --splice-opts "--left-context=2 --right-context=2" 2000 11000 data/train data/$train_lang exp/tri1_ali exp/tri_lda

# echo "===== TRI_LDA (second triphone pass) DECODING ====="
# echo
# utils/mkgraph.sh data/$train_lang exp/tri_lda exp/tri_lda/graph 
# steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri_lda/graph data/test exp/tri_lda/decode


# echo "===== TRI_SAT (third triphone pass) ALIGNMENT ====="
# echo
# steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri_lda exp/tri_lda_ali

# echo "===== TRI_SAT (third triphone pass) SAT Training ====="
# echo


# steps/train_sat.sh  --cmd "$train_cmd" \
# 4200 40000 data/train data/$train_lang exp/tri_lda_ali exp/tri_sat || exit 1;


# echo "===== TRI_LDA (second triphone pass) DECODING ====="
# echo
# utils/mkgraph.sh data/$train_lang exp/tri_sat exp/tri_sat/graph 
# steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri_sat/graph data/test exp/tri_sat/decode


echo ============================================================================
echo "                   End of Script             	        "
echo ============================================================================