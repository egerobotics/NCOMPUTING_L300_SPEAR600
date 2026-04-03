SHELL    := /bin/bash
CHAPTERS := chapters
TXTFILES := $(CHAPTERS)/*.txt
INDEX	 := flasher.txt

.PHONY: clean

all: pdf htm

pdf: $(TXTFILES) $(INDEX) flasher.xml
	        a2x -v -k -f pdf -d book --icons -a data-uri $(INDEX) 

htm: $(TXTFILES) $(INDEX) flasher.xml
	        a2x -v -k -f xhtml -d book -D html --icons -a data-uri $(INDEX) 

flasher.xml:

clean:
	-rm -rf *.pdf *.xml *.tex *.html html/*
