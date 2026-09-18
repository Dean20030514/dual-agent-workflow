using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace TeamRuntime
{
    // Drain redirected pipes without ever writing more than the configured log limit.
    public sealed class BoundedCopy
    {
        private int exceeded;
        private long bytesRead;
        public bool Exceeded => Volatile.Read(ref exceeded) != 0;
        public long BytesRead => Interlocked.Read(ref bytesRead);
        public Task Completion { get; private set; }

        public static BoundedCopy Start(Stream input, Stream output, long limit)
        {
            var copy = new BoundedCopy();
            copy.Completion = copy.CopyAsync(input, output, limit);
            return copy;
        }

        private async Task CopyAsync(Stream input, Stream output, long limit)
        {
            var buffer = new byte[8192];
            long written = 0;
            int read;
            while ((read = await input.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false)) != 0)
            {
                Interlocked.Add(ref bytesRead, read);
                int keep = (int)Math.Min(read, limit - written);
                if (keep < read) Volatile.Write(ref exceeded, 1);
                if (keep > 0)
                {
                    await output.WriteAsync(buffer, 0, keep).ConfigureAwait(false);
                    written += keep;
                }
            }
            await output.FlushAsync().ConfigureAwait(false);
        }

        public static async Task WriteInputAsync(StreamWriter input, string text)
        {
            try
            {
                if (!string.IsNullOrEmpty(text)) await input.WriteAsync(text).ConfigureAwait(false);
            }
            finally { input.Dispose(); }
        }
    }
}
