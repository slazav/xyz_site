all:\
  autiotupa.png\
  vuokratupa.png\
  kota.png\
  laavu.png\
  fire.png\
  luola.png\
  rod.png\
  rodh.png\
  st.png st_h.png ob.png pass.png peak.png def.png\



%.png: %.gif
	convert -trim $< -scale 8% -repage +0+0 PNG32:$@

%.gif: %.fig
	fig2dev -m10 -Lgif -t#ffffff $< $@


clean:
	rm -f -- *.png *.bak