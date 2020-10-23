BEGIN
{
    @ts = 0;
    @kbps = 0;
    @time = 0;

    @bytes = 0;
    @block = 0;
    @n_chunk = 0;

    @mw=0;
    @modew[0]="write";
    @modew[1]="rewrite";
    @modew[2]="random_write";
    @mr=-1;
    @moder[-1]="error";
    @moder[0]="read";
    @moder[1]="reread";
    @moder[2]="random_read";
}


tracepoint:syscalls:sys_exit_openat
/comm == "iozone"/
{
    @time=0;
    @block=0;
}

tracepoint:syscalls:sys_enter_read
/comm == "iozone"/
{
    @ts = nsecs;
    @bytes = args->count;
}

tracepoint:syscalls:sys_exit_read
/comm == "iozone"/
{
  if (@bytes > 4000) {
      @block=@block+@bytes;
      @n_chunk++;
      @time=@time+(nsecs - @ts);
      @flag_read=1;
      @flag_write=0;
  };
}

tracepoint:syscalls:sys_enter_write
/comm == "iozone"/
{
    @ts = nsecs;
    @bytes = args->count;
}

tracepoint:syscalls:sys_exit_write
/comm == "iozone"/
{
  if (@bytes > 4000) {
      @block=@block+@bytes;
      @n_chunk++;
      @time=@time+(nsecs - @ts);
      @flag_read=0;
      @flag_write=1;

  };
}

tracepoint:syscalls:sys_enter_close
/comm == "iozone"/
{
  if (@block>0 && @flag_read==1) {
      @kbps = (@block * 1000000) / @time;
      if (@mr>-1) {
        @read[@block/1024, @bytes/1024, @n_chunk, @moder[@mr]] = @kbps;
      };
      @mr++;
      @mr=@mr%3;
  };

  if (@block>1000 && @flag_write==1) {
      @kbps = (@block * 1000000) / @time;
      @write[@block/1024, @bytes/1024, @n_chunk, @modew[@mw]] = @kbps;
      @mw++;
      @mw=@mw%3;
  };

  @time=0;
  @block=0;
  @n_chunk=0;
  @kbps=0;
}


END
{
    printf("\n       kB, reclen, n_chunks, mode:   kb/s\n");
    print(@write);
    print(@read);
}
