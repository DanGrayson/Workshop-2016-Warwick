PartString = method()
PartString (BasicList) := Partition -> (
  Partition = replace(",","",toString(toList Partition));
  return substring(Partition, 1, #Partition - 2);
)

createNautyString = method(TypicalValue => BasicList)
createNautyString (BasicList, BasicList) := (Polys, Coefficients) -> (
  n := #(Polys#0#0);
  SystemAsLists := new MutableList from for i in 0..n list new MutableList;
  --Monomials := new MutableList;
  CoeffToMonomialNode := new MutableHashTable;
  Polynomials := new MutableList;
  Variables := toList(1..n-1);
  NewNodeRef := n;
  SystemNode = NewNodeRef;
  NewNodeRef = NewNodeRef+1;
  TermToNode := new MutableHashTable;

  for i in 0..#Polys - 1 do (
    PolyNode := NewNodeRef;
    Polynomials = append(Polynomials,NewNodeRef);
    SystemAsLists = append(SystemAsLists,{SystemNode});
    NewNodeRef = NewNodeRef + 1;
    for j in 0..#(Polys#i) - 1 do (
      MonomialNode = NewNodeRef;
      --Monomials = append(Monomials,MonomialNode);
      if CoeffToMonomialNode#?(Coefficients#i#j) then (
         CoeffToMonomialNode#(Coefficients#i#j) = CoeffToMonomialNode#(Coefficients#i#j)|{MonomialNode};
      ) else (
         CoeffToMonomialNode#(Coefficients#i#j) = {MonomialNode};
      );
      SystemAsLists#PolyNode = append(SystemAsLists#PolyNode,MonomialNode);
      SystemAsLists = append(SystemAsLists, new MutableList);
      NewNodeRef = NewNodeRef + 1;
      for k in 0..#(Polys#i#j) - 1 do (
        if Polys#i#j#k != 0 then (
          if TermToNode#?{Polys#i#j#k,k} == false then (
            TermToNode#{Polys#i#j#k,k} = NewNodeRef;
            SystemAsLists = append(SystemAsLists, new MutableList);
            SystemAsLists#k = append(SystemAsLists#k, NewNodeRef);
            NewNodeRef = NewNodeRef + 1;
          );
          SystemAsLists#MonomialNode = append(SystemAsLists#MonomialNode, TermToNode#{Polys#i#j#k,k})
        );
      );
    );
  );
  PartList := new MutableList from {new MutableList};
  ExponentsToPartition := keys TermToNode;
  ExponentsToPartition = sort(ExponentsToPartition);
  CurrentPower := ExponentsToPartition#0#0;
  PowerString := toString CurrentPower | " ";
  for i in 0..#ExponentsToPartition - 1 do (
    PossiblyNewPower = ExponentsToPartition#i#0;
    if CurrentPower != PossiblyNewPower then (
      CurrentPower = PossiblyNewPower;
      PowerString = PowerString | toString CurrentPower | " ";
    );
  );
  if #ExponentsToPartition > 0 then (
    MinValue = ExponentsToPartition#0#0;
  );
  for Key in ExponentsToPartition do (
    if Key#0 != MinValue then (
      PartList = append(PartList, new MutableList);
      MinValue = Key#0;
    );
    PartList#-1 = append(PartList#-1, TermToNode#Key);
  );


  ReturnString := "c -a -m n=" | toString(#SystemAsLists) | " g ";
  for Poly in SystemAsLists do (
    for Term in Poly do (
      ReturnString = ReturnString | toString(Term) | " ";
    );
    ReturnString = ReturnString | ";";
  );
  ReturnString = substring(ReturnString, 0, #ReturnString - 1) | ". f = [ 0 | " | toString(SystemNode) | " | ";
  ReturnString = ReturnString | PartString(Variables) | " | "; 
  print peek CoeffToMonomialNode;
  for NodesWithSameCoefficient in values CoeffToMonomialNode do (
    ReturnString = ReturnString | PartString(NodesWithSameCoefficient) | " | ";
  );
  ReturnString = ReturnString | PartString(Polynomials) | " | ";
  for Part in PartList do (
    ReturnString = ReturnString | PartString(Part) | " | ";
  );
  return ReturnString | "] x @ b";
)


MakeConstIntoVar := Polys -> (
    --This is a helper function to add the constant term into each monomial list.
    --Converting this makes the parsing easier later on.
    Polys = new MutableList from Polys;
    for i in 0..#Polys -1 do (
        Polys#i = new MutableList from Polys#i;
        for j in 0..#(Polys#i)-1 do (
            IsConstant := true;
            for Term in Polys#i#j do (
                if Term != 0 then (
                    IsConstant = false;
                    break;
                );
            );
            if IsConstant then Polys#i#j = {1}|Polys#i#j
            else Polys#i#j = {0}|Polys#i#j;
        );
    );
    return Polys
)

FindSymmetry = Polys-> (
  CoefficientList := new MutableList from for i in 0..#Polys - 1 list new MutableList;
  TermList := new MutableList from for i in 0..#Polys - 1 list new MutableList;
  for i from 0 to #Polys - 1 do (
    Poly = Polys#i;
    for Term in listForm Poly do (
      TermList#i = append(TermList#i,Term#0);
      CoefficientList#i = append(CoefficientList#i,Term#1);
    );
  );
  
  PolysAsLists := MakeConstIntoVar(TermList);
  return createNautyString(PolysAsLists, CoefficientList);
)

dreadnaut'path = prefixDirectory | currentLayout#"programs" | "dreadnaut";
-- Sends a command and retrieves the results into a list of lines.
-- If ReadError is set to true and the command is successfully executed,
-- then the data from stderr is returned (filterGraphs and removeIsomorphs
-- use this).
protect ReadError;
callDreadnaut = method(Options => {ReadError => false})
callDreadnaut (String, List) := List => opts -> (cmdStr, dataList) -> (
    infn := temporaryFileName();
    erfn := temporaryFileName();
    -- output the data to a file
    o := openOut infn;
    scan(graphToString \ dataList, d -> o << d << endl);
    close o;
    -- try to harvest the lines
    r := lines try get openIn ("!" | dreadnaut'path | " <" | infn | " 2>" | erfn)
    else (
        -- nauty errored, harvest the error
        e := last separate(":", first lines get openIn erfn);
        removeFile infn;
        removeFile erfn;
        -- special cases 
        if e == " not found" then error("callDreadnaut: nauty could not be found on the path [" | dreadnaut'path | "].");
        if e == "#q -V] [--keys] [-constraints -v] [ifile [ofile]]" then e = "invalid filter";
        error("callDreadnaut: nauty terminated with the error [", e, "].");
    );
    removeFile infn;
    -- If the method wants it, then read the stderr data instead.
    if opts.ReadError then (
        r = lines try get openIn erfn else (
            removeFile erfn;
            error("callDreadnaut: nauty ran successfully, but no data was written to stderr as expected.  Report this to the package maintainer.");
        );
    );
    removeFile erfn;
    r
)
