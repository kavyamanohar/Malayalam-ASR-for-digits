# RAW DATA 


`/raw` has all the data available at the beginning of the project

- `/wav` (wave files. File names are of the form `utteranceID.wav`)
    - `/train`
    - `/test`
- `/text`(transcript of wave files by the name `utteranceID.lab`)
    - `/train`
    - `/test`
- `/language`
    - `/lexicon` (the phonetic transcript of words in the language vocabulary)

# DATA PREPARATION

From the `/raw` directory a `/data` directory is created with the following contents.

- `/test`
    - `utt` (List of utterance IDs)
    - `wav.scp` (Utterance IDs mapped to absolute wavefile paths)
    - `spk` (List of speaker IDs)
    - `utt2spk` (List of utterences corresponding to a speaker)
    - `spk2utt` (Speaker mapped to every utterance ID)

- `/train`
    - `utt` (List of utterance IDs)
    - `wav.scp` (Utterance IDs mapped to absolute wavefile paths)
    - `spk` (List of speaker IDs)
    - `utt2spk` (List of utterences corresponding to a speaker)
    - `spk2utt` (Speaker mapped to every utterance ID)


# FEATURE EXTRACTION


