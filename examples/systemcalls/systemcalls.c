#include "systemcalls.h"

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
#define     b_TRUE               (bool)1u
#define     b_FALSE              (bool)0u
bool do_system(const char *command)
{

/*
 * TODO  add your code here
 *  Call the system() function with the command set in the cmd
 *   and return a boolean true if the system() call completed with success
 *   or false() if it returned a failure
*/
    return ((system(command)) == 0);   //system returns 0 on successful command execution
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    bool retVal = b_FALSE;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

/*
 * TODO:
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/
    pid_t pid = fork();
    /*From here the code is executed by two processes. Fork return 
     * 0 to the son,
     * >0 to the father.
     * -1 error */
    if(pid == 0)
    {
      //I am the son process and I execute another program
      execv(command[0], command);
      //If execv returns something there is an error
      exit(EXIT_FAILURE);
    }
    else if (pid > 0)
    {
      int status;
      //I am the father process and I wait for my son
      /*Parameters of waitpid function:
       * - pid is the process we need to wait, in this case the process of the son
       * - &status is a pass by reference to store the termination state of that process pid
       * - 0 indicates to wait in a blocking manner, the father process stops until the son finishes*/
      if(waitpid(pid, &status, 0) == -1)
      {
        //waipid returns -1 if fails
        retVal = b_FALSE;
      }
      else
      {
        //Evaluate status of the son
        //WIFEXITED returns true if the son terminated normally, false otherwise
        //WEXITSTATUS returns the exit value of the son
        if(WIFEXITED(status))
        {
          retVal = (bool)(WEXITSTATUS(status) == 0);
        }
        else
        {
          retVal = b_FALSE;
        }
      }
    }
    else
    {
      //This branch should not be reached - fork function has failed
      retVal = b_FALSE;
    }
    
    va_end(args);

    return retVal;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    bool retVal = b_FALSE;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
/*
 * TODO
 *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
 *   redirect standard out to a file specified by outputfile.
 *   The rest of the behaviour is same as do_exec()
 *
*/  
    

  pid_t pid = fork();
  if(pid == 0)
  {
    //open redirect file only in the son
    int fd = open(outputfile, O_WRONLY|O_TRUNC|O_CREAT, 0644);
    if(fd == -1)
    {
      //file descriptor failed
      exit(EXIT_FAILURE);
    }
    else
    {
      //dub2 function redirects output
      if(dup2(fd, STDOUT_FILENO) < 0)
      {
        close(fd);
        exit(EXIT_FAILURE);
      }
      else
      {
        //close file descriptor, is not needed anymore since redirection has been done
        close(fd);
        execv(command[0], command);
        exit(EXIT_FAILURE);
      }
    }
  /*NOTE:
  Notice that the child do not adit value of retVal, reason is that it would be meaningless, remember
  after fork each process has separate variables now, and retVal from son is NOT the same as the retVal 
  from parent. That's why son uses exit() to inform the parent what the status is*/
  }
  else if (pid > 0)
  {
    int status;
    if(waitpid(pid, &status, 0) == -1)
    {
      retVal = b_FALSE;
    }
    else
    {
      if(WIFEXITED(status))
      {
        retVal = (bool)(WEXITSTATUS(status) == 0);
      }
      else
      {
        retVal = b_FALSE;
      }
    }
  }
  else
  {
    retVal = b_FALSE;
  }
    
    va_end(args);
    return retVal;
}
