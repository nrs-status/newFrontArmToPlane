function start-llm-session --description "Bootstrap a new LLM session repo at the given path and launch pi"

    if test (count $argv) -ne 1
        echo "Usage: start_llm_session <path>" >&2
        return 1
    end

    set -l session_dir $argv[1]

    sesh mkdir $session_dir
    cd $session_dir

    git init

    wt switch -c run0

    nvim instructions.txt

    git add instructions.txt
    git commit -m instructions

    pi "Read and execute instructions.txt"
end
