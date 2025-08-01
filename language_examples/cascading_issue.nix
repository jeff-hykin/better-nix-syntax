{
    groupBy = builtins.groupBy or (
    pred: foldl' (r: e:
       let
         key = pred e;
       in
         r // { ${key} = (r.${key} or []) ++ [e]; }
    ) {});
}