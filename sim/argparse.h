#pragma once

#include <string>
#include <cstring>
#include <vector>
#include <map>
#include <variant>

#ifndef ARGPARSE_MAX_STRLEN
#define ARGPARSE_MAX_STRLEN 256
#endif

namespace ArgParse {

// Argument types
enum ArgType_t {UNK, BOOL, INT, FLOAT, STR};

// Argument value
struct ArgVal_t {
    ArgType_t type;
    union {
        bool as_bool;
        long int as_int;
        float as_float;
        char as_str[ARGPARSE_MAX_STRLEN];
    } value;
};

// Argument structure
struct Argument_t{
    std::vector<std::string> aliases;
    ArgType_t type      = UNK;
    std::string key     = "";
    std::string help    = "";
    bool required       = false;
    ArgVal_t defaultval = {.type=UNK, .value={0}};
};

// Convert alias to key
// '--opt-flat' -> 'opt_flat'
std::string alias2key(std::string alias);

// Check if the string is valid for the given type
// 'true', '1', 'false', '0' for BOOL
// '123' for INT
// '123.45' for FLOAT
bool is_valid_type(std::string str, ArgType_t type);

class ArgumentParser {
private:
    std::string prog_name_;
    std::string description_;
    std::string epilog_;
    
    std::vector<Argument_t>         arg_list_;
    std::vector<std::string>        args_;
    std::map<std::string, ArgVal_t> parsed_args_;
    std::vector<std::string>        parsed_pos_args_;

public:
    ArgumentParser(std::string prog_name="", std::string description="", std::string epilog=""):
        prog_name_(prog_name),
        description_(description),
        epilog_(epilog) 
    {
        // Add help argument
        add_argument({"-h", "--help"}, "Show this help message and exit");
    }

    ~ArgumentParser() {}

    void add_argument(std::vector<std::string> aliases, std::string help="", ArgType_t type=BOOL, std::string defaultval="", bool required=false, std::string key="") {
        if(aliases.size() == 0) {
            fprintf(stderr, "ArgParse error: No aliases provided\n");
            return;
        }

        Argument_t arg;
        arg.aliases = aliases;
        arg.help = help;
        arg.type = type;
        arg.required = required;
        if (key == "") {
            // convert the last alias as the key
            arg.key = alias2key(aliases[aliases.size()-1]);
        }
        else {
            arg.key = key;
        }

        if (defaultval != "") {
            if (type == BOOL) {
                arg.defaultval.type = BOOL;
                arg.defaultval.value.as_bool = (defaultval == "true" || defaultval == "1") ? true : false;
            }
            else if (type == INT) {
                arg.defaultval.type = INT;
                arg.defaultval.value.as_int = strtol(defaultval.c_str(), nullptr, 0);
            }
            else if (type == FLOAT) {
                arg.defaultval.type = FLOAT;
                arg.defaultval.value.as_float = strtof(defaultval.c_str(), nullptr);
            }
            else if (type == STR) {
                arg.defaultval.type = STR;
                memccpy(arg.defaultval.value.as_str, defaultval.c_str(), 0, ARGPARSE_MAX_STRLEN);
            }
            else {
                fprintf(stderr, "ArgParse error: Unknown argument type %d\n", type);
                return;
            }  
        }
        else {
            arg.defaultval.type = UNK;
        }
        arg_list_.push_back(arg);
    }

    int parse_args(int argc, char **argv) {
        // Add args
        args_.clear();
        for(int i=0; i<argc; i++) {
            args_.push_back(argv[i]);
        }

        // Take program name from args if not set
        if (prog_name_.size() == 0) {
            prog_name_ = args_[0];
        }

        // add bool args and set default values
        for (auto &a: arg_list_) {
            if (a.type == BOOL) {
                parsed_args_[a.key].type = BOOL;
                parsed_args_[a.key].value.as_bool = false;
            }
            else if(a.defaultval.type != UNK) {
                parsed_args_[a.key].type = a.type;
                parsed_args_[a.key] = a.defaultval;
            }
        }

        // Parse args
        args_.erase(args_.begin()); // remove program name

        size_t i = 0;
        while(i < args_.size()) {
            auto arg = args_[i];
            i++;

            // Check for positional argument
            if (arg[0] != '-') {
                parsed_pos_args_.push_back(arg);
                continue;
            }

            // Check for match
            bool found = false;
            Argument_t *argp=nullptr;
            
            for (auto &a: arg_list_) {
                for (auto alias: a.aliases) {
                    if (alias == arg) {
                        found = true;
                        argp = &a;
                        break;
                    }
                }
                if (found) break;
            }

            if (!found) {
                fprintf(stderr, "ArgParse error: Unknown argument %s\n", arg.c_str());
                return -1;
            }

            if (argp->type == BOOL) {
                parsed_args_[argp->key].type = BOOL;
                parsed_args_[argp->key].value.as_bool = true;
                continue;
            }
            else if (argp->type == INT) {
                if (i >= args_.size()) {
                    fprintf(stderr, "ArgParse error: Missing value for argument %s\n", arg.c_str());
                    return -1;
                }
                if (!is_valid_type(args_[i], INT)) {
                    fprintf(stderr, "ArgParse error: Invalid value for argument %s: %s\n", arg.c_str(), args_[i].c_str());
                    return -1;
                }
                parsed_args_[argp->key].type = INT;
                parsed_args_[argp->key].value.as_int = strtol(args_[i].c_str(), nullptr, 0);
                i++;
            }
            else if (argp->type == FLOAT) {
                if (i >= args_.size()) {
                    fprintf(stderr, "ArgParse error: Missing value for argument %s\n", arg.c_str());
                    return -1;
                }
                if (!is_valid_type(args_[i], FLOAT)) {
                    fprintf(stderr, "ArgParse error: Invalid value for argument %s: %s\n", arg.c_str(), args_[i].c_str());
                    return -1;
                }
                parsed_args_[argp->key].type = FLOAT;
                parsed_args_[argp->key].value.as_float = strtof(args_[i].c_str(), nullptr);
                i++;
            }
            else if (argp->type == STR) {
                if (i >= args_.size()) {
                    fprintf(stderr, "ArgParse error: Missing value for argument %s\n", arg.c_str());
                    return -1;
                }
                if (!is_valid_type(args_[i], STR)) {
                    fprintf(stderr, "ArgParse error: Invalid value for argument %s: %s\n", arg.c_str(), args_[i].c_str());
                    return -1;
                }
                parsed_args_[argp->key].type = STR;
                memccpy(parsed_args_[argp->key].value.as_str, args_[i].c_str(), 0, ARGPARSE_MAX_STRLEN);
                i++;
            }
            else {
                fprintf(stderr, "ArgParse error: Unknown argument type %d\n", argp->type);
                return -1;
            }
        }

        // print help message if requested
        if (parsed_args_["help"].value.as_bool) {
            print_help();
            return -1;
        }

        return 0;
    }

    std::map<std::string, ArgVal_t> get_opt_args()  { return parsed_args_; }
    std::vector<std::string> get_pos_args()         { return parsed_pos_args_; }

    void print_args() {
        printf("Args:\n");
        for (auto k: parsed_args_){
            printf("  %s: ", k.first.c_str());
            switch (k.second.type)
            {
                case BOOL:  printf("<bool> %s\n", k.second.value.as_bool ? "true": "false"); break;
                case INT:   printf("<int> %ld\n", k.second.value.as_int); break;
                case FLOAT: printf("<float> %f\n", k.second.value.as_float); break;
                case STR:   printf("<str> %s\n", k.second.value.as_str); break;
            default:
                printf("<unk> ??"); break;
                break;
            }
        }

        printf("\nPositional Args: [");
        for (auto k: parsed_pos_args_){
            printf("'%s' ", k.c_str());
        }
        printf("]\n");
    }

    void print_help() {
        printf("Usage: %s [options] [args]\n", prog_name_.c_str());

        if(description_.size() > 0)
            printf("Description: %s\n", description_.c_str());

        printf("\nOptions:\n");
        for (auto a: arg_list_){
            if (a.type == BOOL) {
                printf("  ");
                for(size_t i=0; i<a.aliases.size(); i++) {
                    printf("%s%s", a.aliases[i].c_str(), (i == a.aliases.size()-1) ? "  ": ", ");
                }
                printf("  %s\n", a.help.c_str());
            }
            else {
                printf("  %s: %s\n", a.key.c_str(), a.help.c_str());
                for (auto alias: a.aliases) {
                    printf("    %s\n", alias.c_str());
                }
            }
        }

        if(epilog_.size() > 0)
            printf("%s\n", epilog_.c_str());

        printf("\n");
    }
};


// Convert alias to key
// '--opt-flat' -> 'opt_flat'
std::string alias2key(std::string alias) {
    bool arg_started = false;
    std::string key = "";
    for(size_t i=0; i<alias.size(); i++) {
        if (arg_started) {
            if((alias[i] >= 'A' && alias[i] <= 'Z') || 
                (alias[i] >= 'a' && alias[i] <= 'z') || 
                (alias[i] >= '0' && alias[i] <= '9') ||
                (alias[i] == '_')) {
                key += alias[i];
            }
            else if(alias[i] == '-') {
                key += "_";
            }
            else {
                fprintf(stderr, "ArgParse error: Invalid alias %s\n", alias.c_str());
                return key;
            }
        }
        else {
            if(alias[i] == '-') {
                // Skip prefix dashes
            }
            else if((alias[i] >= 'A' && alias[i] <= 'Z') || 
                    (alias[i] >= 'a' && alias[i] <= 'z')) {
                arg_started = true;
                key += alias[i];
            }
            else {
                fprintf(stderr, "ArgParse error: Invalid alias %s\n", alias.c_str());
                return key;
            }
        }
    }
    return key;
}

bool is_valid_type(std::string str, ArgType_t type) {
    if (type == BOOL) {
        return (str == "true" || str == "1" || str == "false" || str == "0");
    }
    else if (type == INT) {
        for (size_t i=0; i<str.size(); i++) {
            if (str[i] < '0' || str[i] > '9') {
                return false;
            }
        }
        return true;
    }
    else if (type == FLOAT) {
        for (size_t i=0; i<str.size(); i++) {
            if (str[i] < '0' || str[i] > '9') {
                if (str[i] == '.' && i != str.size()-1) {
                    continue;
                }
                else if (str[i] == '-' && i == 0) {
                    continue;
                }
                else {
                    return false;
                }
            }
        }
        return true;
    }
    else if (type == STR) {
        return true;
    }
    else {
        fprintf(stderr, "ArgParse error: Unknown argument type %d\n", type);
        return false;
    }
}


}; // namespace ArgParse