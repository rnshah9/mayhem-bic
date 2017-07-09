#include "config.h"
#include "tree.h"
#include "typename.h"
#include "evaluate.h"
#include "gc.h"
#include "replparser.h"
#include "repllex.h"

#ifdef HAVE_LIBREADLINE
#  if defined(HAVE_READLINE_READLINE_H)
#    include <readline/readline.h>
#  elif defined(HAVE_READLINE_H)
#    include <readline.h>
#  else /* !defined(HAVE_READLINE_H) */
extern char *readline ();
#  endif /* !defined(HAVE_READLINE_H) */
char *cmdline = NULL;
#else /* !defined(HAVE_READLINE_READLINE_H) */
#error "No readline found"
#endif /* HAVE_LIBREADLINE */

tree repl_parse_head;
GC_TREE_DECL(repl_parse_head);

void replerror(const char *str)
{
    fprintf(stderr, "Parser Error: %s:%d %s.\n", "<stdin>", repllloc.first_line, str);
    exit(1);
}

void bic_repl()
{
    char *line;

    line = readline(BIC_PROMPT);
    while (line) {
        int parse_result;

        YY_BUFFER_STATE buffer = repl_scan_string(line);
        parse_result = replparse();
        repl_delete_buffer(buffer);

        if (!parse_result) {
            tree_dump(repl_parse_head);
            evaluate(repl_parse_head, "<stdin>");
        }

        line = readline(BIC_PROMPT);
    }
}
