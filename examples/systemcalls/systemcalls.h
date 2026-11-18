#include <stdio.h>
#include <stdbool.h>   //bool
#include <stdlib.h>    //exit
#include <stdarg.h>    //va_list, va_start, va_arg, va_end
#include <unistd.h>    //fork, execv
#include <sys/types.h> //pid_t
#include <sys/wait.h>  //waitpid, WIFEXITED, WEXITSTATUS
#include <fcntl.h>     //open, O_WRONLY, O_CREAT, O_TRUNC

bool do_system(const char *command);

bool do_exec(int count, ...);

bool do_exec_redirect(const char *outputfile, int count, ...);
