all: dist/player.js dist/index.js dist/index.html dist/index.css

dist/player.js: src/player.coffee
	coffee -o dist/ -bc src/player.coffee

dist/index.js: src/index.coffee
	coffee -o dist/ -bc src/index.coffee

dist/index.html: src/index.html
	cp src/index.html dist/index.html

dist/index.css: src/index.css
	cp src/index.css dist/index.css

clean:
	rm -rf dist

.PHONY: clean all
