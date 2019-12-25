divert(-1)
include(parser-lex-funcs.m4)
divert(0)dnl
%{
`#'include <stdio.h>
`#'include <string.h>
`#'include <stdlib.h>
`#'include <stdbool.h>
`#'include "tree.h"
`#'include "typename.h"
`#'include "util.h"
`#'include "TARGET()parser.h"

int TARGET()parse(void);
int TARGET()lex(void);
void TARGET()error(const char *str);

extern tree TARGET()_parse_head;
CFILE_ONLY
    const char *parser_current_file;
REPL_ONLY
    const char *parser_current_file = "<REPL>";
ALL_TARGETS

static void set_locus(tree t, YYLTYPE locus)
{
    tLOCUS(t).line_no = locus.first_line;
    tLOCUS(t).column_no = locus.first_column;

    if(parser_current_file)
        tLOCUS(t).file = get_identifier(parser_current_file);
}

CFILE_ONLY
    void cfile_parser_set_file(const char *fname)
    {
        parser_current_file = fname;
    }
ALL_TARGETS

static tree build_func_ptr(tree ret_type, tree ret_type_ptr,
                           tree ptr, tree id, tree args)
{
    tree function, decl;
    bool is_decl = false;

    if (is_T_TYPEDEF(ret_type)) {
        add_typename(id);
        ret_type = tTYPEDEF_EXP(ret_type);
        is_decl = true;
   }

    ret_type = make_pointer_type(ret_type_ptr, ret_type);

    function = tree_make(T_DECL_FN);
    tFNDECL_NAME(function) = NULL;
    tFNDECL_RET_TYPE(function) = ret_type;
    tFNDECL_ARGS(function) = args;
    tFNDECL_STMTS(function) = NULL;

    if (is_decl)
    {
        tree td = tree_make(T_TYPEDEF);
        tTYPEDEF_EXP(td) = function;
        function = td;
    }

    decl = tree_make(T_DECL);

    if (id) {
        tDECL_TYPE(decl) = function;
        tDECL_DECLS(decl) = make_pointer_type(ptr, id);
    } else
        tDECL_TYPE(decl) = function;

    return decl;
}

static tree handle_declaration(tree type, tree declarator_list)
{
    tree decl = tree_make(T_DECL);
    tDECL_TYPE(decl) = type;
    tDECL_DECLS(decl) = declarator_list;

    /* Check to see if `type' is a typedef. If so, add all identifiers
     * in `declarator_list' to the type_names list.  This will make
     * the lexer tokenise all subsequent instances of the identifier
     * string as a TYPE_NAME token. */
    if (is_T_TYPEDEF(type)) {
        tree i;
        for_each_tree(i, declarator_list) {
            tree oldid = i;

            while (is_T_POINTER(oldid))
                oldid = tPTR_EXP(oldid);

            if (is_T_DECL_FN(oldid))
                oldid = tFNDECL_NAME(oldid);

            if (is_T_ARRAY(oldid))
               oldid = tARRAY_ID(oldid);

            if (!is_T_IDENTIFIER(oldid)) {
                yyerror("Expected identifier when processing typedef");
                return NULL;
            }

            add_typename(oldid);
        }
    }

    return decl;
}


%}

%union
{
    mpz_t integer;
    mpf_t ffloat;
    char *string;
    tree tree;
}

%define parse.error verbose
%locations

%define api.prefix {TARGET}

%token AUTO BREAK CASE CHAR CONST CONTINUE DEFAULT DO
%token DOUBLE ENUM EXTERN FLOAT FOR GOTO IF INT LONG
%token REGISTER RETURN SHORT SIGNED SIZEOF STATIC STRUCT
%token SWITCH TYPEDEF UNION UNSIGNED VOID WHILE
%token EQUATE NOT_EQUATE LESS_OR_EQUAL GREATER_OR_EQUAL
%token SHIFT_LEFT SHIFT_RIGHT BOOL_OP_AND BOOL_OP_OR INC
%token DEC ELLIPSIS PTR_ACCESS BOOL REPL ADD_ASSIGN SUB_ASSIGN
%token DIV_ASSIGN LSHIFT_ASSIGN RSHIFT_ASSIGN XOR_ASSIGN
%token INLINE RESTRICT VOLATILE

%right ')' ELSE

%start translation_unit

%token <tree> IDENTIFIER
REPL_ONLY
  %token <string> C_PRE_INC
ALL_TARGETS
%token <tree> TYPE_NAME
%token <string> CONST_BITS
%token <string> CONST_STRING
%token <integer> INTEGER;
%token <ffloat> FLOAT_CST;
%type <tree> primary_expression
%type <tree> postfix_expression
%type <tree> argument_expression_list
%type <tree> unary_expression
%type <tree> cast_expression
%type <tree> multiplicative_expression
%type <tree> additive_expression
%type <tree> shift_expression
%type <tree> and_expression
%type <tree> exclusive_or_expression
%type <tree> inclusive_or_expression
%type <tree> relational_expression
%type <tree> equality_expression
%type <tree> logical_or_expression
%type <tree> logical_and_expression
%type <tree> assignment_expression
%type <tree> expression
%type <tree> conditional_expression
%type <tree> constant_expression
%type <tree> declaration
%type <tree> declaration_specifiers
%type <tree> init_declarator_list
%type <tree> init_declarator
%type <tree> storage_class_specifier
%type <tree> type_specifier
%type <tree> struct_or_union_specifier
%type <tree> struct_or_union
%type <tree> struct_declaration_list
%type <tree> struct_declaration
%type <tree> specifier_qualifier_list
%type <tree> struct_declarator_list
%type <tree> struct_declarator
%type <tree> enum_specifier
%type <tree> enumerator_list
%type <tree> enumerator
%type <tree> type_qualifier
%type <tree> function_specifier
%type <tree> declarator
%type <tree> direct_declarator
%type <tree> pointer
%type <tree> type_qualifier_list
%type <tree> parameter_type_list
%type <tree> parameter_list
%type <tree> parameter_declaration
%type <tree> identifier_list
%type <tree> type_name
%type <tree> abstract_declarator
%type <tree> direct_abstract_declarator
%type <tree> initializer
%type <tree> initializer_list
%type <tree> designation
%type <tree> designator_list
%type <tree> designator
%type <tree> statement
%type <tree> labeled_statement
%type <tree> compound_statement
%type <tree> block_item_list
%type <tree> block_item
%type <tree> expression_statement
%type <tree> selection_statement
%type <tree> iteration_statement
%type <tree> jump_statement
%type <tree> translation_unit
%type <tree> external_declaration
%type <tree> function_definition
%type <tree> declaration_list

%%

primary_expression
: INTEGER
{
    tree number = tree_make(T_INTEGER);
    mpz_init_set(tINT_VAL(number), $1);
    mpz_clear($1);
    set_locus(number, @1);
    $$ = number;
}
| FLOAT_CST
{
    tree ffloat = tree_make(T_FLOAT);
    mpf_init_set(tFLOAT_VAL(ffloat), $1);
    mpf_clear($1);
    set_locus(ffloat, @1);
    $$ = ffloat;
}
| IDENTIFIER
{
    tree identifier = $1;
    set_locus(identifier, @1);
    $$ = identifier;
}
| CONST_STRING
{
    tree str = tree_make(T_STRING);
    tSTRING_VAL(str) = $1;
    set_locus(str, @1);
    $$ = str;
}
| '(' expression ')'
{
    $$ = $2;
}
;

postfix_expression
: primary_expression
| postfix_expression '(' ')'
{
    tree fncall = tree_make(T_FN_CALL);
    tFNCALL_ID(fncall) = $1;
    tFNCALL_ARGS(fncall) = NULL;
    set_locus(fncall, @1);
    $$ = fncall;
}
| postfix_expression '(' argument_expression_list ')'
{
    tree fncall = tree_make(T_FN_CALL);
    tFNCALL_ID(fncall) = $1;
    tFNCALL_ARGS(fncall) = $3;
    set_locus(fncall, @1);
    $$ = fncall;
}
| postfix_expression '[' expression ']'
{
    tree arr_access = tree_make(T_ARRAY_ACCESS);
    tARR_ACCESS_OBJ(arr_access) = $1;
    tARR_ACCESS_IDX(arr_access) = $3;
    set_locus(arr_access, @1);
    $$ = arr_access;
}
| postfix_expression INC
{
    tree inc = tree_make(T_P_INC);
    tPINC_EXP(inc) = $1;
    set_locus(inc, @2);
    $$ = inc;
}
| postfix_expression DEC
{
    tree dec = tree_make(T_P_DEC);
    tPDEC_EXP(dec) = $1;
    set_locus(dec, @2);
    $$ = dec;
}
| postfix_expression '.' IDENTIFIER
{
    tree access = tree_make(T_COMP_ACCESS);
    tCOMP_ACCESS_OBJ(access) = $1;
    tCOMP_ACCESS_MEMBER(access) = $3;
    set_locus(access, @2);
    set_locus(tCOMP_ACCESS_MEMBER(access), @3);
    $$ = access;
}
| postfix_expression PTR_ACCESS IDENTIFIER
{
    tree deref = tree_make(T_DEREF);
    tree access = tree_make(T_COMP_ACCESS);

    tDEREF_EXP(deref) = $1;
    tCOMP_ACCESS_OBJ(access) = deref;
    tCOMP_ACCESS_MEMBER(access) = $3;

    set_locus(deref, @2);
    set_locus(access, @2);

    $$ = access;
}
;

argument_expression_list
: assignment_expression
{
    $$ = tree_chain_head($1);
}
| argument_expression_list ',' assignment_expression
{
    tree_chain($3, $1);
}
;

unary_expression
: postfix_expression
| INC unary_expression
{
    tree inc = tree_make(T_INC);
    tINC_EXP(inc) = $2;
    set_locus(inc, @1);
    $$ = inc;
}
| DEC unary_expression
{
    tree dec = tree_make(T_DEC);
    tDEC_EXP(dec) = $2;
    set_locus(dec, @1);
    $$ = dec;
}
| '!' unary_expression
{
    tree negate = tree_make(T_NEGATE);
    tNEGATE_EXP(negate) = $2;
    set_locus(negate, @1);
    $$ = negate;
}
| '&' unary_expression
{
    tree addr = tree_make(T_ADDR);
    tADDR_EXP(addr) = $2;
    set_locus(addr, @1);
    $$ = addr;
}
| '*' unary_expression
{
    tree deref = tree_make(T_DEREF);
    tDEREF_EXP(deref) = $2;
    set_locus(deref, @1);
    $$ = deref;
}
| SIZEOF unary_expression
{
    tree szof = tree_make(T_SIZEOF);
    tSZOF_EXP(szof) = $2;
    set_locus(szof, @1);
    $$ = szof;
}
| SIZEOF '(' type_name ')'
{
    tree szof = tree_make(T_SIZEOF);
    tSZOF_EXP(szof) = $3;
    set_locus(szof, @1);
    $$ = szof;
}
;

cast_expression
: unary_expression
| '(' type_name ')' cast_expression
{
    tree cast = tree_make(T_CAST);
    tCAST_NEWTYPE(cast) = $2;
    tCAST_EXP(cast) = $4;
    set_locus(cast, @1);
    $$ = cast;
}
;

multiplicative_expression
: cast_expression
| multiplicative_expression '*' cast_expression
{
    tree mul = tree_make(T_MUL);
    tMUL_LHS(mul) = $1;
    tMUL_RHS(mul) = $3;
    set_locus(mul, @2);
    $$ = mul;
}
| multiplicative_expression '/' cast_expression
{
    tree div = tree_make(T_DIV);
    tDIV_LHS(div) = $1;
    tDIV_RHS(div) = $3;
    set_locus(div, @2);
    $$ = div;
}
| multiplicative_expression '%' cast_expression
{
    tree mod = tree_make(T_MOD);
    tMOD_LHS(mod) = $1;
    tMOD_RHS(mod) = $3;
    set_locus(mod, @2);
    $$ = mod;
}
;

additive_expression
: multiplicative_expression
| additive_expression '+' multiplicative_expression
{
    tree add = tree_make(T_ADD);
    tADD_LHS(add) = $1;
    tADD_RHS(add) = $3;
    set_locus(add, @2);
    $$ = add;
}
| additive_expression '-'  multiplicative_expression
{
    tree sub = tree_make(T_SUB);
    tSUB_LHS(sub) = $1;
    tSUB_RHS(sub) = $3;
    set_locus(sub, @2);
    $$ = sub;
}
;

shift_expression
: additive_expression
| shift_expression SHIFT_LEFT additive_expression
{
    tree lshift = tree_make(T_LSHIFT);
    tLSHIFT_LHS(lshift) = $1;
    tLSHIFT_RHS(lshift) = $3;
    set_locus(lshift, @2);
    $$ = lshift;
}
| shift_expression SHIFT_RIGHT additive_expression
{
    tree rshift = tree_make(T_RSHIFT);
    tRSHIFT_LHS(rshift) = $1;
    tRSHIFT_RHS(rshift) = $3;
    set_locus(rshift, @2);
    $$ = rshift;
}
;

relational_expression
: shift_expression
| relational_expression '<' shift_expression
{
    tree lt = tree_make(T_LT);
    tLT_LHS(lt) = $1;
    tLT_RHS(lt) = $3;
    $$ = lt;
}
| relational_expression '>' shift_expression
{
    tree gt = tree_make(T_GT);
    tGT_LHS(gt) = $1;
    tGT_RHS(gt) = $3;
    set_locus(gt, @2);
    $$ = gt;
}
| relational_expression LESS_OR_EQUAL shift_expression
{
    tree ltoreq = tree_make(T_LTEQ);
    tLTEQ_LHS(ltoreq) = $1;
    tLTEQ_RHS(ltoreq) = $3;
    set_locus(ltoreq, @2);
    $$ = ltoreq;
}
| relational_expression GREATER_OR_EQUAL shift_expression
{
    tree gtoreq = tree_make(T_GTEQ);
    tGTEQ_LHS(gtoreq) = $1;
    tGTEQ_RHS(gtoreq) = $3;
    set_locus(gtoreq, @2);
    $$ = gtoreq;
}
;

equality_expression
: relational_expression
| equality_expression EQUATE relational_expression
{
    tree equal = tree_make(T_EQ);
    tEQ_LHS(equal) = $1;
    tEQ_RHS(equal) = $3;
    set_locus(equal, @2);
    $$ = equal;
}
| equality_expression NOT_EQUATE relational_expression
{
    tree not_equal = tree_make(T_N_EQ);
    tN_EQ_LHS(not_equal) = $1;
    tN_EQ_RHS(not_equal) = $3;
    set_locus(not_equal, @2);
    $$ = not_equal;
}
;

and_expression
: equality_expression
| and_expression '&' equality_expression
{
    tree inclusive_and = tree_make(T_I_AND);
    tI_AND_LHS(inclusive_and) = $1;
    tI_AND_RHS(inclusive_and) = $3;
    set_locus(inclusive_and, @2);
    $$ = inclusive_and;
}
;

exclusive_or_expression
: and_expression
| exclusive_or_expression '^' and_expression
{
    tree exclusive_or = tree_make(T_X_OR);
    tX_OR_LHS(exclusive_or) = $1;
    tX_OR_RHS(exclusive_or) = $3;
    set_locus(exclusive_or, @2);
    $$ = exclusive_or;
}
;

inclusive_or_expression
: exclusive_or_expression
| inclusive_or_expression '|' exclusive_or_expression
{
    tree inclusive_or = tree_make(T_I_OR);
    tI_OR_LHS(inclusive_or) = $1;
    tI_OR_RHS(inclusive_or) = $3;
    set_locus(inclusive_or, @2);
    $$ = inclusive_or;
}

logical_and_expression
: inclusive_or_expression
| logical_and_expression BOOL_OP_AND inclusive_or_expression
{
    tree logicand = tree_make(T_L_AND);
    tL_AND_LHS(logicand) = $1;
    tL_AND_RHS(logicand) = $3;
    set_locus(logicand, @2);
    $$ = logicand;
}

logical_or_expression
: logical_and_expression
| logical_or_expression BOOL_OP_OR logical_and_expression
{
    tree logicor = tree_make(T_L_OR);
    tL_OR_LHS(logicor) = $1;
    tL_OR_RHS(logicor) = $3;
    set_locus(logicor, @2);
    $$ = logicor;
}
;

conditional_expression
: logical_or_expression
| logical_or_expression '?' expression ':' conditional_expression
{
    tree infix = tree_make(T_INFIX);
    tINFIX_COND(infix) = $1;
    tINFIX_TRUE_STMT(infix) = $3;
    tINFIX_FALSE_STMT(infix) = $5;
    $$ = infix;
}

constant_expression
: conditional_expression
;

assignment_expression
: conditional_expression
| unary_expression '=' assignment_expression
{
    tree assign = tree_make(T_ASSIGN);
    tASSIGN_LHS(assign) = $1;
    tASSIGN_RHS(assign) = $3;
    set_locus(assign, @2);
    $$ = assign;
}
| unary_expression ADD_ASSIGN assignment_expression
{
    $$ = tree_make_binmod(T_ADD, tADD, $1, $3);
}
| unary_expression SUB_ASSIGN assignment_expression
{
    $$ = tree_make_binmod(T_SUB, tSUB, $1, $3);
}
| unary_expression  DIV_ASSIGN assignment_expression
{
    $$ = tree_make_binmod(T_DIV, tDIV, $1, $3);
}
| unary_expression LSHIFT_ASSIGN assignment_expression
{
    $$ = tree_make_binmod(T_LSHIFT, tLSHIFT, $1, $3);
}
| unary_expression RSHIFT_ASSIGN assignment_expression
{
    $$ = tree_make_binmod(T_RSHIFT, tRSHIFT, $1, $3);
}
| unary_expression XOR_ASSIGN assignment_expression
{
$$ = tree_make_binmod(T_X_OR, tX_OR, $1, $3);
}
;

expression
: assignment_expression
{
    $$ = tree_chain_head($1);
}
| expression ',' assignment_expression
{
    tree_chain($3, $1);
}
;

constant_expression
: conditional_expression
;

declaration
: declaration_specifiers ';'
| declaration_specifiers init_declarator_list ';'
;

declaration_specifiers
: storage_class_specifier
| storage_class_specifier declaration_specifiers
| type_specifier
| type_specifier declaration_specifiers
| type_qualifier
| type_qualifier declaration_specifiers
| function_specifier
| function_specifier declaration_specifiers
;

init_declarator_list
: init_declarator
| init_declarator_list ',' init_declarator
;

init_declarator
: declarator
| declarator '=' initializer
;

storage_class_specifier
: TYPEDEF
| EXTERN
| STATIC
| AUTO
| REGISTER
;

type_specifier
: VOID
| CHAR
| SHORT
| INT
| LONG
| FLOAT
| DOUBLE
| SIGNED
| UNSIGNED
| BOOL
| struct_or_union_specifier
| enum_specifier
| TYPE_NAME
;

struct_or_union_specifier
: struct_or_union IDENTIFIER '{' struct_declaration_list '}'
| struct_or_union '{' struct_declaration_list '}'
| struct_or_union IDENTIFIER
;

struct_or_union
: STRUCT
| UNION
;

struct_declaration_list
: struct_declaration
| struct_declaration_list struct_declaration
;

struct_declaration
: specifier_qualifier_list struct_declarator_list ';'
;

specifier_qualifier_list
: type_specifier specifier_qualifier_list
| type_specifier
| type_qualifier specifier_qualifier_list
| type_qualifier
;

struct_declarator_list
: struct_declarator
| struct_declarator_list ',' struct_declarator
;

struct_declarator
: declarator
| ':' constant_expression
| declarator ':' constant_expression
;

enum_specifier
: ENUM '{' enumerator_list '}'
| ENUM IDENTIFIER '{' enumerator_list '}'
| ENUM '{' enumerator_list ',' '}'
| ENUM IDENTIFIER '{' enumerator_list ',' '}'
| ENUM IDENTIFIER
;

enumerator_list
: enumerator
| enumerator_list ',' enumerator
;

enumerator
: IDENTIFIER
| IDENTIFIER '=' constant_expression
;

type_qualifier
: CONST
| RESTRICT
| VOLATILE
;

function_specifier
: INLINE
;

declarator
: pointer direct_declarator
| direct_declarator
;


direct_declarator
: IDENTIFIER
| '(' declarator ')'
| direct_declarator '[' type_qualifier_list assignment_expression ']'
| direct_declarator '[' type_qualifier_list ']'
| direct_declarator '[' assignment_expression ']'
| direct_declarator '[' STATIC type_qualifier_list assignment_expression ']'
| direct_declarator '[' type_qualifier_list STATIC assignment_expression ']'
| direct_declarator '[' type_qualifier_list '*' ']'
| direct_declarator '[' '*' ']'
| direct_declarator '[' ']'
| direct_declarator '(' parameter_type_list ')'
| direct_declarator '(' identifier_list ')'
| direct_declarator '(' ')'
;

pointer
: '*'
| '*' type_qualifier_list
| '*' pointer
| '*' type_qualifier_list pointer
;

type_qualifier_list
: type_qualifier
| type_qualifier_list type_qualifier
;

parameter_type_list
: parameter_list
| parameter_list ',' ELLIPSIS
;

parameter_list
: parameter_declaration
| parameter_list ',' parameter_declaration
;

parameter_declaration
: declaration_specifiers declarator
| declaration_specifiers abstract_declarator
| declaration_specifiers
;

identifier_list
: IDENTIFIER
| identifier_list ',' IDENTIFIER
;

type_name
: specifier_qualifier_list
| specifier_qualifier_list abstract_declarator
;

abstract_declarator
: pointer
| direct_abstract_declarator
| pointer direct_abstract_declarator
;

direct_abstract_declarator
: '(' abstract_declarator ')'
| '[' ']'
| '[' assignment_expression ']'
| direct_abstract_declarator '[' ']'
| direct_abstract_declarator '[' assignment_expression ']'
| '[' '*' ']'
| direct_abstract_declarator '[' '*' ']'
| '(' ')'
| '(' parameter_type_list ')'
| direct_abstract_declarator '(' ')'
| direct_abstract_declarator '(' parameter_type_list ')'
;

initializer
: assignment_expression
| '{' initializer_list '}'
| '{' initializer_list ',' '}'
;

initializer_list
: initializer
| designation initializer
| initializer_list ',' initializer
| initializer_list ',' designation initializer
;

designation
: designator_list '='
;

designator_list
: designator
| designator_list designator
;

designator
: '[' constant_expression ']'
| '.' IDENTIFIER
;

statement
: labeled_statement
| compound_statement
| expression_statement
| selection_statement
| iteration_statement
| jump_statement
;

labeled_statement
: IDENTIFIER ':' statement
| CASE constant_expression ':' statement
| DEFAULT ':' statement
;

compound_statement
: '{' '}'
| '{' block_item_list '}'
;

block_item_list
: block_item
| block_item_list block_item
;

block_item
: declaration
| statement
;

expression_statement
: ';'
| expression ';'
;

selection_statement
: IF '(' expression ')' statement
| IF '(' expression ')' statement ELSE statement
| SWITCH '(' expression ')' statement
;

iteration_statement
: WHILE '(' expression ')' statement
| DO statement WHILE '(' expression ')' ';'
| FOR '(' expression_statement expression_statement ')' statement
| FOR '(' expression_statement expression_statement expression ')' statement
| FOR '(' declaration expression_statement ')' statement
| FOR '(' declaration expression_statement expression ')' statement
;

jump_statement
: GOTO IDENTIFIER ';'
| CONTINUE ';'
| BREAK ';'
| RETURN ';'
| RETURN expression ';'
;

translation_unit
: external_declaration
| translation_unit external_declaration
;

external_declaration
: function_definition
| declaration
;

function_definition
: declaration_specifiers declarator declaration_list compound_statement
| declaration_specifiers declarator compound_statement
;

declaration_list
: declaration
| declaration_list declaration
;
