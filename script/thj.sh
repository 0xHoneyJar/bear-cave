#!/bin/bash

# Function to display usage
usage() {
    echo "THJ Utility Belt";
    echo "";
    echo "Usage: $0 -n <network> <method>  [--no-load-env] [--broadcast] [--no-verify] [--resume]"
    echo "";
    echo "Description: Utility belt for THJ on-chain commands for <method>."
    echo "             Loads environment variables from .env and a file specific to the <network> parameter  "
    echo "Options:"
    echo "  -n, --network       : The network for which the .env file should be loaded. Expected filename(.env.<network>). (Required)"
    echo "  -n2 --network2      : Second Network to config against"
    echo "  <method>            : The method to be performed. Supported methods are (Required)" 
    echo "                         - Options [testnetDeps|deploy|config|addBundle|setGates|startGame]"
    echo "  --no-load-env       : Optional flag to skip loading environment variables from .env file."
    echo "  --broadcast         : Optional flag to append '--broadcast' to the forge command."
    echo "  --no-verify         : Optional flag to remove append '--verify' from the forge command when --broadcast is active"
    echo "  --resume            : Optional flag to append '--resume' to the forge command."
}

# Set default values
broadcast=false
resume=false
load_env=true
network=""
network2=""
method=""
forge_params=""
no_verify=false

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
    --no-verify)
      no_verify=true
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
    -n2|--network2)
     network2="$2"
     shift 2
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
forge_params="--rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow -vvvv"

if [ "$broadcast" = true ]; then
  forge_params="${forge_params} --broadcast"
  if [ "$no_verify" = false ]; then
    forge_params="$forge_params --verify"
  fi
fi

if [ "$resume" = true ]; then
  forge_params="${forge_params} --resume"
fi

# For some reason this doesn't work need to manully put --sig in all calls.
sig="--sig 'run(string)()' $network"

# Space for funsies
echo ""

# Perform different methods based on the parameter passed
case "$method" in
  "localNode")
    echo "Running local fork of $network"
    anvil --fork-url $RPC_URL
    ;;
  "test")
    echo "Forge Params ${forge_params}"
    forge script script/TestScript.s.sol:TestScript --sig 'run(string)()' $network $forge_params
    ;;
  "testnetDeps")
    echo "Running testnetDeps"
    forge script script/100_TestnetDeps.s.sol:TestnetDeps --sig 'run(string)()' $network $forge_params
    ;;
  "deploy1")
    echo "Deploying Gatekeeper & GameRegistry"
    forge script script/00_Deploy.s.sol:DeployScript --sig 'deployHelpers(string)()' $network $forge_params
    ;;
  "deploy2")
    echo "Deploying Token"
    forge script script/00_Deploy.s.sol:DeployScript --sig 'deployToken(string)()' $network $forge_params
    ;;
  "deploy3")
    echo "Deploying HibernationDen"
    forge script script/00_Deploy.s.sol:DeployScript --sig 'deployHibernationDen(string)()' $network $forge_params
    ;;
  "deploy4")
    echo "Deploying HoneyJarPortal"
    forge script script/00_Deploy.s.sol:DeployScript --sig 'deployHoneyJarPortal(string)()' $network $forge_params
    ;;
  "config")
    echo "Configuring Game"
    forge script script/01_ConfigureGame.s.sol:ConfigureGame --sig 'run(string)()' $network $forge_params
    ;;
  "config-portals")
    echo "Configuring Portals between $network and $network2"
    forge script script/01_ConfigureGame.s.sol:ConfigureGame --sig 'configurePortals(string,string)()' $network $network2 $forge_params
    ;;        
  "addBundle") 
    echo "Running addBundle"
    forge script script/02_BundleTokens.s.sol:BundleTokens --sig 'run(string)()' $network $forge_params
    ;;
  "setGates")
    echo "Running setGates"
    forge script script/03_SetGates.s.sol:SetGates --sig 'run(string)()' $network $forge_params
    ;;
  "startGame")
    echo "Running startGame"
    forge script script/04_StartGame.s.sol:StartGame --sig 'run(string)()' $network $forge_params
    ;;
  "sendJars")
    echo "Running sendJars"
    forge script script/05_SendJars.s.sol:SendFermentedJars --sig 'run(string)()' $network $forge_params
    ;;
  "addToParty")
    echo "Running sendJars"
    forge script script/06_AddToParty.s.sol:AddToParty --sig 'run(string)()' $network $forge_params
    ;;
  "testnetApprove")
    echo "Running testnetApprove"
    forge script script/101_TestnetPuffPuff.s.sol:TestnetPuffPuff --sig 'run(string)()' $network $forge_params
    ;;
  "testnetPuffPuff")
    echo "Running testnetPuffPuff"
    forge script script/101_TestnetPuffPuff.s.sol:TestnetPuffPuff --sig 'estimateAndPuff(string)()' $network $forge_params
    ;;
  "validate")
    echo "Running testnetPuffPuff"
    forge script script/200_Validate.t.sol:ValidateScript --sig 'validate(string,string)()' $network $network2 $forge_params
    ;;
  *)
    echo "Error: Unsupported method."
    usage
    exit 1
    ;;
esac
