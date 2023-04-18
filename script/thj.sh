#!/bin/bash

# Function to display usage
usage() {
    echo "THJ Utility Belt";
    echo "";
    echo "Usage: $0 -n <network> <method>  [--no-load-env] [--broadcast] [--resume]"
    echo "";
    echo "Description: Utility belt for THJ on-chain commands for <method>."
    echo "             Loads environment variables from .env and a file specific to the <network> parameter  "
    echo "Options:"
    echo "  -n, --network       : The network for which the .env file should be loaded. Expected filename(.env.<network>). (Required)"
    echo "  <method>            : The method to be performed. Supported methods are (Required)" 
    echo "                         - Options [testnetDeps|deploy|config|addBundle|setGates|startGame]"
    echo "  --no-load-env       : Optional flag to skip loading environment variables from .env file."
    echo "  --broadcast         : Optional flag to append '--broadcast' to the forge command."
    echo "  --resume            : Optional flag to append '--resume' to the forge command."
}

# Set default values
broadcast=false
resume=false
load_env=true
network=""
method=""
forge_params=""

# Check if at least three arguments are provided
if [ "$#" -lt 3 ]; then
    usage
    exit 1
fi

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-load-env)
      load_env=false
      shift
      ;;
    --broadcast)
      broadcast=true
      shift
      ;;
    --resume)
      resume=true
      shift
      ;;
    -n|--network)
      if [ -n "$2" ]; then
        network="$2"
        shift 2
      else
        echo "Error: Network parameter value missing"
        usage
        exit 1
      fi
      ;;
    *)
      if [ -z "$method" ]; then
        method="$1"
      fi
      shift
      ;;
  esac
done

# Check if method is provided
if [ -z "$method" ]; then
  usage
  exit 1
fi

# Check if network is provided
if [ -z "$network" ]; then
  echo "Error: Network parameter missing"
  usage
  exit 1
fi

# Load environment variables from .env file if flag is provided
if [ "$load_env" = true ]; then
  echo "Loading environment variables from file: .env ..."
  source .env
  env_file=".env.${network}"
  if [ ! -f "$env_file" ]; then
    echo "Error: .env file for network '$network' not found"
    exit 1
  fi
  echo "Loading environment variables from file: $env_file ..."
  source "$env_file"
fi


# Build forge params
# Append --broadcast to the forge param if flag is provided
forge_params="--rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow -vvvvv"

if [ "$broadcast" = true ]; then
  forge_params="${forge_params} --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY"
fi

if [ "$resume" = true ]; then
  forge_params="${forge_params} --resume"
fi

# Space for funsies
echo ""

# Perform different methods based on the parameter passed
case "$method" in
  "test")
    echo "Forge Params ${forge_params}"
    ;;
  "testnetDeps")
    echo "Running testnetDeps"
    forge script script/100_TestnetDeps.s.sol:TestnetDeps $forge_params
    ;;
  "deploy")
    echo "Running deploy"
    forge script script/00_Deploy.s.sol:DeployScript $forge_params
    ;;
  "config")
    echo "Running config"
    forge script script/01_ConfigureGame.s.sol:ConfigureGame $forge_params
    ;;    
  "addBundle") 
    echo "Running addBundle"
    forge script script/02_BundleTokens.s.sol:BundleTokens $forge_params
    ;;
  "setGates")
    echo "Running setGates"
    forge script script/03_SetGates.s.sol:SetGates $forge_params
    ;;
  "startGame")
    echo "Running startGame"
    forge script script/04_StartGame.s.sol:StartGame $forge_params
    ;;
  *)
    echo "Error: Unsupported method."
    usage
    exit 1
    ;;
esac
