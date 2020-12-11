/* -*- buffer-read-only: t -*-
   !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
   This file is built by regen_perly.pl from perly.y.
   Any changes made here will be lost!
 */

#define PERL_BISON_VERSION  30005

#ifdef PERL_CORE
/* A Bison parser, made by GNU Bison 3.5.1.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2020 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* Undocumented macros, especially those whose name start with YY_,
   are private implementation details.  Do not rely on them.  */

/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token type.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    GRAMPROG = 258,
    GRAMEXPR = 259,
    GRAMBLOCK = 260,
    GRAMBARESTMT = 261,
    GRAMFULLSTMT = 262,
    GRAMSTMTSEQ = 263,
    GRAMSUBSIGNATURE = 264,
    PERLY_AMPERSAND = 265,
    PERLY_BRACE_OPEN = 266,
    PERLY_BRACE_CLOSE = 267,
    PERLY_BRACKET_OPEN = 268,
    PERLY_BRACKET_CLOSE = 269,
    PERLY_COMMA = 270,
    PERLY_DOT = 271,
    PERLY_EQUAL_SIGN = 272,
    PERLY_SEMICOLON = 273,
    BAREWORD = 274,
    METHOD = 275,
    FUNCMETH = 276,
    THING = 277,
    PMFUNC = 278,
    PRIVATEREF = 279,
    QWLIST = 280,
    FUNC0OP = 281,
    FUNC0SUB = 282,
    UNIOPSUB = 283,
    LSTOPSUB = 284,
    PLUGEXPR = 285,
    PLUGSTMT = 286,
    LABEL = 287,
    FORMAT = 288,
    SUB = 289,
    SIGSUB = 290,
    ANONSUB = 291,
    ANON_SIGSUB = 292,
    PACKAGE = 293,
    USE = 294,
    WHILE = 295,
    UNTIL = 296,
    IF = 297,
    UNLESS = 298,
    ELSE = 299,
    ELSIF = 300,
    CONTINUE = 301,
    FOR = 302,
    GIVEN = 303,
    WHEN = 304,
    DEFAULT = 305,
    LOOPEX = 306,
    DOTDOT = 307,
    YADAYADA = 308,
    FUNC0 = 309,
    FUNC1 = 310,
    FUNC = 311,
    UNIOP = 312,
    LSTOP = 313,
    MULOP = 314,
    ADDOP = 315,
    DOLSHARP = 316,
    DO = 317,
    HASHBRACK = 318,
    NOAMP = 319,
    LOCAL = 320,
    MY = 321,
    REQUIRE = 322,
    COLONATTR = 323,
    FORMLBRACK = 324,
    FORMRBRACK = 325,
    SUBLEXSTART = 326,
    SUBLEXEND = 327,
    PREC_LOW = 328,
    OROP = 329,
    DOROP = 330,
    ANDOP = 331,
    NOTOP = 332,
    ASSIGNOP = 333,
    OROR = 334,
    DORDOR = 335,
    ANDAND = 336,
    BITOROP = 337,
    BITANDOP = 338,
    CHEQOP = 339,
    NCEQOP = 340,
    CHRELOP = 341,
    NCRELOP = 342,
    SHIFTOP = 343,
    MATCHOP = 344,
    UMINUS = 345,
    REFGEN = 346,
    POWOP = 347,
    PREINC = 348,
    PREDEC = 349,
    POSTINC = 350,
    POSTDEC = 351,
    POSTJOIN = 352,
    ARROW = 353
  };
#endif

/* Value type.  */
#ifdef PERL_IN_TOKE_C
static bool
S_is_opval_token(int type) {
    switch (type) {
    case BAREWORD:
    case FUNC0OP:
    case FUNC0SUB:
    case FUNCMETH:
    case LABEL:
    case LSTOPSUB:
    case METHOD:
    case PLUGEXPR:
    case PLUGSTMT:
    case PMFUNC:
    case PRIVATEREF:
    case QWLIST:
    case THING:
    case UNIOPSUB:
	return 1;
    }
    return 0;
}
#endif /* PERL_IN_TOKE_C */
#endif /* PERL_CORE */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{

    I32	ival; /* __DEFAULT__ (marker for regen_perly.pl;
				must always be 1st union member) */
    char *pval;
    OP *opval;
    GV *gvval;


};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif



int yyparse (void);


/* Generated from:
 * dc3a381751f2897cbaa6dc2f792cd125a225072206d399dd4981603f81f78a24 perly.y
 * acf1cbfd2545faeaaa58b1cf0cf9d7f98b5be0752eb7a54528ef904a9e2e1ca7 regen_perly.pl
 * ex: set ro: */
