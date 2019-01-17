#include "utils_manager.h"
#ifdef __QNX__
#include <sys/syspage.h>
#include <sys/debug.h>
#else
#include <libgen.h>
#endif
#include <string.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <dirent.h>
#include <stdlib.h>
#include <spawn.h>
#include <errno.h>
#include <fstream>
#include <unistd.h>

#include "common/constants.h"
#include "rpc/detail/log.h"

#ifndef __QNX__
extern char **environ;//need for posix_spawn
#endif

namespace utils_wrappers {

const char * const kPostFixBackup = "_origin";

using namespace constants;

RPCLIB_CREATE_LOG_CHANNEL(UtilsManager)

//-----Monitor of the running applications until they terminates-----------------------------
static void * thread_monitor_app(void * pid)
{
    if(!pid){
        return 0;
    }

    pid_t app_pid = *(static_cast<pid_t*>(pid));
    delete static_cast<pid_t*>(pid);

    int status = 0;

     do {

        if(0 > waitpid(app_pid, &status, WUNTRACED | WCONTINUED)){
            break;
        }

        if(WIFEXITED(status)){
            LOG_INFO("app_id:{0} exited, status:{1}=%d\n",app_pid, WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            LOG_INFO("app_id:{0} killed by signal:{1}",app_pid, WTERMSIG(status));
        } else if (WIFSTOPPED(status)) {
            LOG_INFO("app_id:{0} stopped by signal:{1}",app_pid, WSTOPSIG(status));
        } else if (WIFCONTINUED(status)) {
            LOG_INFO("app_id:{0} continued",app_pid);
        }

    }while (!WIFEXITED(status) && !WIFSIGNALED(status));

    return 0;
}
//------------------------------------------------------------------------------
int UtilsManager::StartApp(const std::string & app_path,const std::string & app_name){
    LOG_INFO("{0}: {1}",__func__,app_name);

    char cwd[PATH_MAX] = {0};
    getcwd(cwd, sizeof(cwd));
    chdir(app_path.c_str());

    char * const argv[] = {strdup(app_name.c_str()),NULL};

    pid_t app_pid = error_codes::FAILED;
    posix_spawn(&app_pid,argv[0],NULL,NULL, argv,environ);

    chdir(cwd);
    free(argv[0]);

    if(error_codes::FAILED != app_pid){
        if(0 == kill(app_pid,0)){
            pthread_t thread_id;
            pid_t * app_pid_ptr = new pid_t(app_pid);
            int result = pthread_create(&thread_id,0,
                                        &thread_monitor_app,app_pid_ptr);
            if(0 != result){
                delete app_pid_ptr;
            }

            return constants::error_codes::SUCCESS;
        }
    }

    LOG_ERROR("{}",strerror(errno));
    return error_codes::FAILED;
}

int UtilsManager::StopApp(const std::string & app_name,const int sig){
    LOG_INFO("{0}: {1}",__func__,app_name);

    ArrayPid arr_pid = GetPidApp(app_name);
    bool is_all_killed = true;

    for(const auto & app_pid : arr_pid){
        if(error_codes::FAILED == KillApp(app_pid,sig,app_name.c_str())){
            is_all_killed = false;
        }
    }

    if(is_all_killed){
        return error_codes::SUCCESS;
    }

    is_all_killed = true;
    for(const auto & app_pid : arr_pid){
        if(IsExistsApp(app_pid)){
            if(error_codes::FAILED == KillApp(app_pid,SIGKILL,app_name.c_str())){
                is_all_killed = false;
            }
        }
    }

    return is_all_killed ?
           error_codes::SUCCESS
           :
           error_codes::FAILED;
}

int UtilsManager::CheckStatusApp(const std::string & app_name){
    LOG_INFO("{}",__func__);    
    ArrayPid arr_pid = GetPidApp(app_name);
    if(0 == arr_pid.size()){
        LOG_INFO("{} is NOT_RUNNING",app_name);
        return stat_app_codes::NOT_RUNNING;
    }

    int num_threads = 0;

    procfs_info info;

    for(const auto & app_pid : arr_pid){
        GetNameApp(app_pid,&info);
#ifdef __QNX__
        num_threads += info.num_threads;
#else
        num_threads += info;
#endif
    }

    LOG_INFO("{0} has: {1} thread",app_name,num_threads);
    if(num_threads > 1){
        LOG_INFO("{0} is RUNNING\n",app_name);
        return stat_app_codes::RUNNING;
    }
    LOG_INFO("{} is CRASHED\n",app_name);
    return stat_app_codes::CRASHED;
}

int UtilsManager::FileBackup(const std::string & file_path,const std::string & file_name){
    LOG_INFO("{}",__func__);    
    std::string file_dest_path =
                        JoinPath(
                            file_path,
                            file_name)
                            .append(kPostFixBackup);

    std::ifstream src(JoinPath(file_path,file_name).c_str(), std::ios::binary);
    std::ofstream dest(file_dest_path.c_str(), std::ios::binary);
    dest << src.rdbuf();

    return src && dest ?
        error_codes::SUCCESS
        :
        error_codes::FAILED;
}

int UtilsManager::FileRestore(const std::string & file_path,const std::string & file_name){
    LOG_INFO("{}",__func__);
    std::string file_src_path =
                        JoinPath(
                            file_path,
                            file_name)
                            .append(kPostFixBackup);

    std::ifstream src(file_src_path.c_str(), std::ios::binary);
    std::ofstream dest(JoinPath(file_path,file_name).c_str(), std::ios::binary);
    dest << src.rdbuf();

    FileDelete(file_path,std::string(file_name).append(kPostFixBackup));

    return src && dest ?
        error_codes::SUCCESS
        :
        error_codes::FAILED;
}

int UtilsManager::FileUpdate(const std::string & file_path,const std::string & file_name,const std::string & file_content){    
    LOG_INFO("{}",__func__);    
    std::ofstream ofs (JoinPath(file_path,file_name).c_str(),std::ofstream::binary);
    ofs << file_content.c_str();
    return ofs ?
        error_codes::SUCCESS
        :
        error_codes::FAILED;
}

int UtilsManager::FileExists(const std::string & file_path,const std::string & file_name){
    LOG_INFO("{}",__func__);
    struct stat stat_buff;
    return 0 == (stat(JoinPath(file_path,file_name).c_str(), &stat_buff)) ?
        error_codes::SUCCESS
        :
		error_codes::FAILED;
}

int UtilsManager::FileDelete(const std::string & file_path,const std::string & file_name){
    LOG_INFO("{}",__func__);
    if(remove(JoinPath(file_path,file_name).c_str()) != 0 ){
        return error_codes::FAILED;
    }
    return error_codes::SUCCESS;
}

std::string UtilsManager::GetFileContent(
    const std::string & file_path,
    const std::string & file_name,
    size_t & offset,
    const size_t max_size_content)
{
    LOG_INFO("{}",__func__);
	FILE * hfile = fopen(JoinPath(file_path,file_name).c_str(), "rb");
	if (!hfile){
		LOG_ERROR("Unable to open file: {}",JoinPath(file_path,file_name));
        offset = error_codes::FAILED;
		return std::string();
	}

    fseek(hfile, 0, SEEK_END);
	unsigned long fileLen = ftell(hfile) - offset;
	fseek(hfile, offset, SEEK_SET);
    LOG_INFO("File offset: {0} rest size of the file: {1}",offset,fileLen);
    if(max_size_content){
        fileLen = max_size_content > fileLen ?
                            fileLen
                            :
                            max_size_content;
    }

    char * buffer = (char *)malloc(fileLen);
	if (!buffer){
		LOG_TRACE("Memory error!");
        fclose(hfile);
        offset = error_codes::FAILED;
		return std::string();
	}

    fread(buffer, fileLen, 1, hfile);
    fseek(hfile, 0, SEEK_END);

    size_t read = fileLen;
	fileLen = ftell(hfile);
	fclose(hfile);

    offset = (read + offset) == fileLen ?
                    error_codes::SUCCESS
                    :
                    read + offset;

	std::string file_content(buffer,read);

    LOG_INFO("New file offset: {}",offset);
	free(buffer);
    return file_content;
}

int UtilsManager::FolderExists(const std::string & folder_path){
    LOG_INFO("{}",__func__);
    struct stat stat_buff;
    return 0 == (stat(folder_path.c_str(), &stat_buff)) ?
        error_codes::SUCCESS
        :
        error_codes::FAILED;
}

int UtilsManager::FolderDelete(const std::string & folder_path){
    LOG_INFO("{}",__func__);
    DIR * dir = opendir(folder_path.c_str());
    size_t path_len = folder_path.length();
    int res = -1;

    if (dir){
        struct dirent * ent_dir;
        res = 0;

        while(!res && (ent_dir = readdir(dir))){
            char * buff;
            size_t len;

            if(!strcmp(ent_dir->d_name, ".") || !strcmp(ent_dir->d_name, "..")){
                continue;
            }

            res = -1;
            len = path_len + strlen(ent_dir->d_name) + 2;
            buff = static_cast<char *>(malloc(len));

            if(buff){
                struct stat statbuf;
                snprintf(buff, len, "%s/%s", folder_path.c_str(), ent_dir->d_name);

                if(!stat(buff, &statbuf)){
                    if(S_ISDIR(statbuf.st_mode)){
                        res = FolderDelete(buff);
                    }else{
                        res = unlink(buff);
                    }
                }

                free(buff);
            }
        }
        closedir(dir);
    }

    if(!res){
        res = rmdir(folder_path.c_str());
    }

    return res;
}

int UtilsManager::FolderCreate(const std::string & folder_path){
    LOG_INFO("{}",__func__);
    const int dir_err = mkdir(folder_path.c_str(), S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    if (-1 == dir_err){
        printf("\nError creating directory: %s",folder_path.c_str());
        return error_codes::FAILED;
    }
    return error_codes::SUCCESS;
}

UtilsManager::ReceiveResult UtilsManager::ExecuteCommand(const std::string & bash_command){
    LOG_INFO("{0}: {1}",__func__,bash_command);
    std::string command_output;
    char buffer[128] = {0};
    FILE* pipe = popen(bash_command.c_str(), "r");
    if (!pipe){
        return std::make_pair(command_output,error_codes::FAILED);
    }

    try{

        while(!feof(pipe)){
            if(fgets(buffer, 128, pipe) != NULL){
                command_output += buffer;
            }
        }

    }catch(...){
        pclose(pipe);
        command_output.clear();
        return std::make_pair(command_output,error_codes::FAILED);
    }

    int term_status = pclose(pipe);
    term_status = (-1 != term_status) ? WEXITSTATUS( term_status ) : error_codes::FAILED;

    term_status = (0 == term_status) ?
                error_codes::SUCCESS
                :
                error_codes::FAILED;

    return std::make_pair(command_output,term_status);
}

UtilsManager::ArrayPid UtilsManager::GetPidApp(const std::string & app_name){

    struct dirent   *dirent;
    DIR             *dir;
    int             app_pid;

    if (!(dir = opendir ("/proc"))) {
    fprintf (stderr, "\ncouldn't open /proc, errno %d\n",errno);
    perror (NULL);
    return ArrayPid();
    }

    ArrayPid arr_pid;

    while(dirent = readdir (dir)){
        if(isdigit (*dirent -> d_name)){
            app_pid = atoi (dirent -> d_name);
            if(0 == app_name.compare(GetNameApp(app_pid))){
                arr_pid.push_back(app_pid);
            }
        }
    }

    closedir (dir);

    return arr_pid;
}

std::string UtilsManager::GetNameApp(int app_pid,procfs_info * proc_info){

    char      paths [PATH_MAX];
#ifdef __QNX__
    int       fd;
    static struct {
    procfs_debuginfo    info;
    char                buff [BUFSIZ];
    } name;

    sprintf (paths, "/proc/%d/as", app_pid);

    if ((fd = open (paths, O_RDONLY)) == -1) {
        return "";
    }

    if(devctl (fd, DCMD_PROC_MAPDEBUG_BASE, &name,sizeof (name), 0) != EOK){
        if(app_pid == 1){
            strcpy (name.info.path, "/(procnto)");
        }else{
            strcpy (name.info.path, "/(n/a)");
        }
    }

    if(proc_info){
        int sts = devctl (fd, DCMD_PROC_INFO,proc_info, sizeof (procfs_info), NULL);
        if (sts != EOK){
            fprintf(stderr, "\n%s: DCMD_PROC_INFO pid %d errno %d (%s)",
            strrchr(name.info.path, '/') + 1, app_pid, errno, strerror (errno));
        }
    }

    close (fd);

    if(char * app_name = strrchr(name.info.path, '/')){
        return std::string(app_name + 1);
    }

    return std::string(name.info.path);

#else

    if(proc_info){
        *proc_info = 0;

        struct dirent   *dirent;
        DIR             *dir;

        sprintf(paths, "/proc/%d/task",app_pid);

        if (dir = opendir (paths)){
            while(dirent = readdir (dir)){
                if(isdigit (*dirent -> d_name)){
                    ++(*proc_info);
                }
            }
            closedir (dir);
        }
    }

    sprintf(paths, "/proc/%d/cmdline", app_pid);
    if(FILE * hFile = fopen(paths, "r")){
        size_t size = fread(paths,sizeof(char),sizeof(paths),hFile);
        fclose(hFile); 
		if(size > 0){
            if('\n' == paths[size - 1]){
                paths[size - 1] = '\0';
            }
            if(char * app_name = strrchr(paths, '/')){
                return std::string(app_name + 1);
            }
            return std::string(paths);
		}
		
    }
    return "";
#endif
}

int UtilsManager::KillApp(const pid_t app_pid,const int sig,const char * app_name){

    errno = 0;
    kill(app_pid,sig);

    if(false == IsExistsApp(app_pid)){
        LOG_INFO("Succes kill pid: {0} app: {1}\n",
                 app_pid,app_name ? app_name : "");
        return constants::error_codes::SUCCESS;
    }

    switch(errno){
        case EAGAIN:
        LOG_ERROR("Failed kill pid: {0} app: {1} "
                "Insufficient system resources are"
                "available to deliver the signal."
                ,app_pid,app_name ? app_name : "");
                break;
        case EINVAL:
        LOG_ERROR("Failed kill pid: {0} app: {1} "
                "The sig is invalid."
                ,app_pid,app_name ? app_name : "");
        break;
        case EPERM:
        LOG_ERROR("Failed kill pid: {0} app: {1} "
                "The process doesn't have permission to"
                "send this signal to any receiving process."
                ,app_pid,app_name ? app_name : "");
        break;
        case ESRCH:
        LOG_ERROR("Failed kill pid: {0} app: {1} "
                "The given pid doesn't exist.\n"
                ,app_pid,app_name ? app_name : "");
        break;
        default:
            LOG_ERROR("Failed kill pid: {0} app: {1}"
                      "Unknown error in errno\n"
                      ,app_pid,app_name ? app_name : "");
    }

    return constants::error_codes::FAILED;
}

bool UtilsManager::IsExistsApp(const pid_t app_pid){

    struct stat stat_buff;
    char        proc_path[PATH_MAX];

    sprintf(proc_path,"/proc/%d",app_pid);

    return 0 == (stat(proc_path, &stat_buff));
}

std::string UtilsManager::JoinPath(const std::string & path,const std::string & part_path){

    std::string full_path = path;

    if('/' != full_path[full_path.length() -1]){
        full_path += '/';
    }

    return full_path.append(part_path);
}

}  // namespace utils_wrappers
