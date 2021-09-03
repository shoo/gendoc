import std.stdio;

version (Hoge)
{
	static assert(0, "The default configuration was selected.");
}
void main()
{
}
