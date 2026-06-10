# Support

## Getting Help

- **Documentation**: [README.md](./README.md) — architecture, quick start, services
- **Issues**: [GitHub Issues](https://github.com/faisalaffan/infra-light/issues) — bug reports, feature requests
- **Discussions**: [GitHub Discussions](https://github.com/faisalaffan/infra-light/discussions) — Q&A, ideas

## Common Issues

### kubectl hangs after setup.sh
```bash
# Check wrapper script
cat ~/.local/bin/kubectl
# Should call /usr/local/bin/kubectl, not itself
# Fix: re-run setup.sh (auto-detected and fixed)
```

### DNS not working in pods
```bash
# Check UFW
sudo ufw status | grep 6443
# Fix: sudo ufw allow 6443/tcp
```

### postgres-all ImagePullBackOff
```bash
# Pull manually
sudo k3s ctr images pull docker.io/faisalaffan/postgres-all:latest
# Or check Docker Hub: https://hub.docker.com/r/faisalaffan/postgres-all
```

## Contact

Email: faisallionel@gmail.com
