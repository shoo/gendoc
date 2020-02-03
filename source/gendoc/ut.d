/***************************************************************
 * Features for unit testing
 * 
 * Fine-tune the output destination of coverage, etc.
 */
module gendoc.ut;

debug shared static this()
{
	import core.stdc.stdio;
	setvbuf(stdout, null, _IONBF, 0);
}
