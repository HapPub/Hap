try:
    require(sys.version_info >= (3,11), 'Python 3.11 or newer is required for host tools')
    args=sys.argv[1:]
    if args[:2]==['get','ssh']:result=ssh_get(args[2:])
    elif args[:1]==['get']:result=installer_main(args[1:])
    elif args[:1]==['installer']:result=installer_main(args[1:])
    elif args[:1]==['ssh']:result=ssh_main(args[1:])
    else:raise ValueError('unknown host command')
    emit(**result);sys.exit(0 if result.get('ok') else 2)
except (ValueError,OSError,KeyError,TypeError,subprocess.SubprocessError) as error:
    # Wire paths catch and sanitize their own errors. Do not echo argv or code.
    emit(ok=False,status='host-operation-failed',detail=str(error)[:500]);sys.exit(2)
except KeyboardInterrupt:
    emit(ok=False,status='cancelled');sys.exit(130)
