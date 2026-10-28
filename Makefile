CC = clang
CFLAGS = -O2 -Wall -Wextra -fobjc-arc

dockhop: main.m
	$(CC) $(CFLAGS) main.m -o $@ -framework AppKit -framework Carbon

clean:
	rm -f dockhop

.PHONY: clean
