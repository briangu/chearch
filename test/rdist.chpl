use ReplicatedDist;

const Dbase = {1..5};
const Drepl: domain(1) dmapped ReplicatedDist() = Dbase;
var Abase: [Dbase] int;
var Arepl: [Drepl] int;

writeln("init:");
writeln("Abase");
writeln(Abase);
writeln("Arepl");
writeln(Arepl);
writeln();

// only the current locale's replicand is accessed
Arepl[3] = 4;

writeln("assignment:");
writeln("Abase");
writeln(Abase);
writeln("Arepl");
writeln(Arepl);
writeln();

// these iterate over Dbase, so
// only the current locale's replicand is accessed
writeln("zip a:");
Arepl[1] = 8;
writeln("Abase");
writeln(Abase);
writeln("Arepl");
writeln(Arepl);

forall (b,r) in zip(Abase,Arepl) do b = r;
Abase = Arepl;

writeln("Abase");
writeln(Abase);
writeln("Arepl");
writeln(Arepl);
writeln();

// these iterate over Drepl;
// each replicand will be zippered against (and copied from) the entire Abase
writeln("zip b:");
Abase[2] = 9;
writeln("Abase");
writeln(Abase);
writeln("Arepl");
writeln(Arepl);

forall (r,b) in zip(Arepl,Abase) do r = b;
Arepl = Abase;

writeln("Abase");
writeln(Abase);
writeln("Arepl");
writeln(Arepl);
writeln();
