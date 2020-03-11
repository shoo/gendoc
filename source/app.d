/*******************************************************************************
 * Main source file
 */
module app;

import gendoc.main;

version(gendoc_app) int main(string[] args)
{
	return gendocMain(args);
}
