K8S_NODE=192.168.99.100

here=`cd $(dirname $BASH_SOURCE); pwd`
chart=$here
launchAgentConfig="${chart}/launchAgent.yaml"
agentPod="${chart}/agent.yaml"
namespace="demo-helm"
release="demo"

function copyPassword {
    case `uname` in
      Darwin)
        copyToClipboard=pbcopy
        ;;
      Linux)
        copyToClipboard="xclip -selection clipboard"
        ;;
    esac
    echo `kubectl get secret --namespace $namespace ${release}-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode` | `$copyToClipboard`
}

function waitJenkins {
  echo "Waiting for Jenkins"
  set +x
  until nc -z $K8S_NODE 31465; do
    sleep 1
  done
  set -x
}

function start {
  helm install -n $release --namespace $namespace $chart
  waitJenkins
  copyPassword
  helm upgrade $release -f $launchAgentConfig $chart
  kubectl apply -f $agentPod -n $namespace
  open http://${K8S_NODE}:31465
}

function stop {
  helm delete --purge `helm ls -aq`
  kubectl delete pod/demo-jenkins-remoting-kafka-agent -n $namespace
  kubectl delete `kubectl get pvc -A -o name` -n $namespace
}

cmd=$1
set -x
case $cmd in
  start)
    start
    ;;
  stop)
    stop
    ;;
  reset)
    stop
    sleep 60
    start
    ;;
  *)
    echo "Invalid command"
    ;;
esac