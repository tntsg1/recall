#!/usr/bin/env bash
# Regenerate every still the visual review uses into proofs/review/.
cd "$(dirname "$0")/.."
for t in title_shots hud_shots review_shots host_hud_shots possess_shots band_shots resume_shots; do
	timeout 260 bash tools/run_test.sh tests/$t.gd --fixed-fps 60 > /dev/null 2>&1 || echo "FAILED $t"
done
R=proofs/review
for f in ui/1_assemble ui/2_menu ui/4_page_in ui/8_opening ui/9_cards_rising ui/10_cards ui/11b_card_flight ui/12_pause ui/h_intro_150 ui/h_boss_bar ui/h_stamp ui/band_full possess/band_3_host possess/band_2_ready_ping possess/1_marks possess/2_drill; do
	cp proofs/$f.png $R/$(echo $f | tr / _).png
done
cp proofs/ui/resume_100.png $R/ui_resume_chapter.png
cp proofs/ui/resume_230.png $R/ui_resume_wave.png
echo "review stills: $(ls $R/*.png | wc -l)"
