/*******************************************************************************
 * Misc types or functions
 * 
 * Provides versatile misc functions.
 */
module gendoc.misc;

import std.traits;

/*******************************************************************************
 * 
 */
enum MacroType
{
	/// $xxx, ${xxx}
	str,
	/// $(DOLLAR)(xxx)
	expr
}

/*******************************************************************************
 * Expands macro variables contained within a str
 */
T expandMacro(T, Func)(in T str, Func mapFunc)
	if (isSomeString!T
	&& isCallable!Func
	&& is(ReturnType!Func: bool)
	&& ParameterTypeTuple!Func.length >= 1
	&& is(T: ParameterTypeTuple!Func[0])
	&& (ParameterStorageClassTuple!Func[0] & ParameterStorageClass.ref_) == ParameterStorageClass.ref_)
{
	bool func(ref T arg, MacroType type, bool expandRecurse)
	{
		if (expandRecurse)
			arg = arg.expandMacroImpl!(T, func)();
		static if (ParameterTypeTuple!Func.length == 1)
		{
			return mapFunc(arg);
		}
		else
		{
			return mapFunc(arg, type);
		}
	}
	return str.expandMacroImpl!(T, func)();
}

/// ditto
T expandMacro(T, Func)(in T str, Func mapFunc)
	if (isSomeString!T
	&& isCallable!Func
	&& is(ReturnType!Func: T)
	&& ParameterTypeTuple!Func.length >= 1
	&& is(T: ParameterTypeTuple!Func[0]))
{
	bool func(ref T arg, MacroType type, bool expandRecurse)
	{
		if (expandRecurse)
			arg = arg.expandMacroImpl!(T, func)();
		static if (ParameterTypeTuple!Func.length == 1)
		{
			arg = mapFunc(arg);
		}
		else
		{
			arg = mapFunc(arg, type);
		}
		return true;
	}
	
	return str.expandMacroImpl!(T, func)();
}

/// ditto
T expandMacro(T, MAP)(in T str, MAP map)
	if (isSomeString!T
	&& is(typeof({ auto p = T.init in map; T tmp = *p; })))
{
	bool func(ref T arg, MacroType type, bool expandRecurse)
	{
		if (expandRecurse)
			arg = arg.expandMacroImpl!(T, func)();
		if (auto p = arg in map)
		{
			arg = *p;
			return true;
		}
		return false;
	}
	return str.expandMacroImpl!(T, func)();
}


private size_t searchEnd1(Ch)(const(Ch)[] str)
{
	size_t i = 0;
	import std.regex;
	if (auto m = str.match(ctRegex!(cast(Ch[])`^[a-zA-Z_].*?\b`)))
	{
		return m.hit.length;
	}
	return -1;
}

@system unittest
{
	assert(searchEnd1("abcde-fgh") == 5);
	assert(searchEnd1("abcde$fgh") == 5);
	assert(searchEnd1("abcde_fgh") == 9);
	assert(searchEnd1("abcde") == 5);
	assert(searchEnd1("$abcde") == -1);
	assert(searchEnd1("") == -1);
}

private size_t searchEnd2(Ch)(const(Ch)[] str, Ch ch)
{
	size_t i = 0;
	while (i < str.length)
	{
		if (str[i] == ch)
			return i;
		if (str[i] == '$')
		{
			if (i+1 < str.length)
			{
				// 連続する$$は無視
				if (str[i+1] == '$')
				{
					i+=2;
					continue;
				}
				if (str[i+1] == '(')
				{
					auto i2 = searchEnd2(str[i+2..$], ')');
					if (i2 == -1)
						return -1;
					i += i2 + 3;
				}
				else if (str[i+1] == '{')
				{
					auto i2 = searchEnd2(str[i+2..$], '}');
					if (i2 == -1)
						return -1;
					i += i2 + 3;
				}
				else
				{
					auto i2 = searchEnd1(str[i+1..$]);
					if (i2 == -1)
						return -1;
					i += i2 + 1;
				}
			}
			else
			{
				return -1;
			}
		}
		else
		{
			++i;
		}
	}
	return -1;
}
@system unittest
{
	assert(searchEnd2("abcde-f)gh", ')') == 7);
	assert(searchEnd2("abcde$f)gh", ')') == 7);
	assert(searchEnd2("abcde_f)gh", ')') == 7);
	assert(searchEnd2("abcde_fgh)", ')') == 9);
	assert(searchEnd2("abcde_$(f)gh)", ')') == 12);
	assert(searchEnd2("abcde_${f}gh)xx", ')') == 12);
}

private T expandMacroImpl(T, alias func)(in T str)
	if (isSomeString!T
	&& isCallable!func
	&& is(ReturnType!func: bool)
	&& ParameterTypeTuple!func.length == 3
	&& is(T:         ParameterTypeTuple!func[0])
	&& is(MacroType: ParameterTypeTuple!func[1])
	&& is(bool:      ParameterTypeTuple!func[2])
	&& (ParameterStorageClassTuple!func[0] & ParameterStorageClass.ref_) == ParameterStorageClass.ref_)
{
	import std.array, std.algorithm;
	Appender!T result;
	T rest = str[];
	size_t idxBegin, idxEnd;
	
	while (1)
	{
		idxBegin = rest.countUntil('$');
		if (idxBegin == -1 || idxBegin+1 >= rest.length)
			return result.data ~ rest;
		
		result ~= rest[0..idxBegin];
		
		if (rest[idxBegin+1] == '(')
		{
			auto head = rest[idxBegin..idxBegin+2];
			rest = rest[idxBegin+2..$];
			idxEnd = searchEnd2(rest, ')');
			if (idxEnd == -1)
				return result.data ~ head ~ rest;
			assert(rest[idxEnd] == ')');
			auto tmp = rest[0..idxEnd];
			if (func(tmp, MacroType.expr, true))
			{
				result ~= tmp;
				rest    = rest[idxEnd+1..$];
			}
			else
			{
				result ~= head ~ tmp ~ rest[idxEnd..idxEnd+1];
				rest    = rest[idxEnd+1..$];
			}
		}
		else if (rest[idxBegin+1] == '{')
		{
			auto head = rest[idxBegin..idxBegin+2];
			rest = rest[idxBegin+2..$];
			idxEnd = searchEnd2(rest, '}');
			if (idxEnd == -1)
				return result.data ~ head ~ rest;
			assert(rest[idxEnd] == '}');
			auto tmp = rest[0..idxEnd];
			if (func(tmp, MacroType.str, true))
			{
				result ~= tmp;
				rest    = rest[idxEnd+1..$];
			}
			else
			{
				result ~= head ~ tmp ~ rest[idxEnd..idxEnd+1];
				rest    = rest[idxEnd+1..$];
			}
		}
		else if (rest[idxBegin+1] == '$')
		{
			result ~= rest[idxBegin+1];
			rest = rest[idxBegin+2..$];
		}
		else
		{
			auto head = rest[idxBegin..idxBegin+1];
			rest = rest[idxBegin+1..$];
			idxEnd = searchEnd1(rest);
			if (idxEnd == -1)
				return result.data ~ rest;
			auto tmp = rest[0..idxEnd];
			if (func(tmp, MacroType.str, false))
			{
				result ~= tmp;
				rest    = rest[idxEnd..$];
			}
			else
			{
				result ~= head ~ tmp;
				rest    = rest[idxEnd..$];
			}
		}
	}
	assert(0);
}

@system unittest
{
	import std.meta;
	assert("x${$(aaa)x}${$(aaa)y}".expandMacro(["aaa": "AAA", "AAAx": "BBB"]) == "xBBB${AAAy}");
	static foreach (T; AliasSeq!(string, wstring, dstring))
	{{
		T str = "test$(xxx)${zzz}test$$${yyy}";
		T[T] map = ["xxx": "XXX", "yyy": "YYY"];
		assert(str.expandMacro(map) == "testXXX${zzz}test$YYY");
		assert(expandMacro(cast(T)"test$(yyy", map) == "test$(yyy");
		assert(expandMacro(cast(T)"test${zzz", map) == "test${zzz");
		
		auto foo = function T(T arg)
		{
			if (arg == cast(T)"xxx")
				return cast(T)"XXX";
			if (arg == cast(T)"abcXXX")
				return cast(T)"yyy";
			return cast(T)"ooo";
		};
		assert(expandMacro(cast(T)"xxx$yyy$(abc${xxx})", foo) == "xxxoooyyy");
		
		auto bar = delegate bool(ref T arg)
		{
			if (arg == cast(T)"xxx")
			{
				arg = cast(T)"XXX";
				return true;
			}	
			if (arg == cast(T)"abcXXX")
			{
				arg = cast(T)"yyy";
				return true;
			}
			return false;
		};
		assert(expandMacro(cast(T)"xxx$yyy$(abc${xxx})", bar) == "xxx$yyyyyy");
		assert(expandMacro(cast(T)"xxx$(aaa)", bar) == "xxx$(aaa)");
		assert(expandMacro(cast(T)"xxx$$(aaa)", bar) == "xxx$(aaa)");
		assert(expandMacro(cast(T)"xxx$(a$$aa)", bar) == "xxx$(a$aa)");
		assert(expandMacro(cast(T)"xxx$(a$(aa", bar) == "xxx$(a$(aa");
		assert(expandMacro(cast(T)"xxx$(a$...", bar) == "xxx$(a$...");
		assert(expandMacro(cast(T)"xxx$(a$", bar) == "xxx$(a$");
		
		auto foo2 = function T(T arg, MacroType ty)
		{
			if (arg == cast(T)"xxx")
				return ty == MacroType.str ? cast(T)"XXX1" : cast(T)"XXX2";
			if (arg == cast(T)"abcXXX1")
				return ty == MacroType.str ? cast(T)"yyy1" : cast(T)"yyy2";
			return ty == MacroType.str ? cast(T)"ooo1" : cast(T)"ooo2";
		};
		assert(expandMacro(cast(T)"xxx$yyy$(abc${xxx})", foo2) == "xxxooo1yyy2");
		assert(expandMacro(cast(T)"xxx$yyy$(abc${xxx}", foo2) == "xxxooo1$(abc${xxx}");
		assert(expandMacro(cast(T)"xxx$yyy$(abc${xxx", foo2) == "xxxooo1$(abc${xxx");
		assert(expandMacro(cast(T)"xxx$...", foo2) == "xxx...");
		
		auto bar2 = delegate bool(ref T arg, MacroType ty)
		{
			if (arg == cast(T)"xxx")
			{
				arg = ty == MacroType.str ? cast(T)"XXX1" : cast(T)"XXX2";
				return true;
			}	
			if (arg == cast(T)"abcXXX1")
			{
				arg = ty == MacroType.str ? cast(T)"yyy1" : cast(T)"yyy2";
				return true;
			}
			return false;
		};
		assert(expandMacro(cast(T)"xxx$yyy$(abc${xxx})", bar2) == "xxx$yyyyyy2");
		assert(expandMacro(cast(T)"xxx$yyy$(abc${xxx}", bar2) == "xxx$yyy$(abc${xxx}");
	}}
}

