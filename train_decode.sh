#set-up for single machine or cluster based execution
. ./cmd.sh
#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh


train_dict=dict
train_lang=lang_bigram
train_folder=train


echo "===== MONO TRAINING ====="
echo

nj=1
steps/train_mono.sh --nj $nj --cmd "$train_cmd"  data/train data/$train_lang exp/mono  || exit 1

echo
echo "===== MONO ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/$train_lang exp/mono exp/mono_ali || exit 1

echo
echo "===== TRI1 (first triphone pass) TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/$train_lang exp/mono_ali exp/tri1 || exit 1


echo "===== TRI_LDA (second triphone pass) ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri1 exp/tri1_ali

echo "===== TRI_LDA (second triphone pass) LDA Training ====="
echo

steps/train_lda_mllt.sh --splice-opts "--left-context=2 --right-context=2" 2000 11000 data/train data/$train_lang exp/tri1_ali exp/tri_lda


echo "===== TRI_SAT (third triphone pass) ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri_lda exp/tri_lda_ali

echo "===== TRI_SAT (third triphone pass) SAT Training ====="
echo


steps/train_sat.sh  --cmd "$train_cmd" \
4200 40000 data/train data/$train_lang exp/tri_lda_ali exp/tri_sat || exit 1;




echo
echo "===== MONO DECODING ====="
echo
utils/mkgraph.sh --mono data/$train_lang exp/mono exp/mono/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode



echo "===== TRI1 (first triphone pass) DECODING ====="
echo
utils/mkgraph.sh data/$train_lang exp/tri1 exp/tri1/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode

echo "===== TRI_LDA (second triphone pass) DECODING ====="
echo
utils/mkgraph.sh data/$train_lang exp/tri_lda exp/tri_lda/graph 
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri_lda/graph data/test exp/tri_lda/decode


echo "===== TRI_LDA (second triphone pass) DECODING ====="
echo
utils/mkgraph.sh data/$train_lang exp/tri_sat exp/tri_sat/graph 
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri_sat/graph data/test exp/tri_sat/decode


echo ============================================================================
echo "                   End of Script             	        "
echo ============================================================================