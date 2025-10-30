{
    a32432 = [ 1 2 3 ];
    b32432 = [ a b c ];
    c32432 = [ a.b b.c.d ];
    d32432 = [a.b b.c.d];
    e32432 = [ a.${thing}.b b.c.d ];
    e32432 = [ a.${thing}.b (b.c.d "foo") ];
}