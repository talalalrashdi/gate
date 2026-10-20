using System.Security.Cryptography;

namespace CompanyPortal.Api.Data;

// This reviewed, self-contained asset uses embedded PNGs and CSS animation.
// Trust exact bytes, never a filename, client flag or SVG-supplied metadata.
public static class BundledArtwork
{
    private static readonly byte[] NationalDayHash = Convert.FromHexString("321DD36C5EBC5615AEDEE18BC6C1C78EC2D8B4C8A1D803A2395639CF36E1260A");
    public static bool IsNationalDay(byte[] data) =>
        data.Length <= ImageValidation.MaximumBytes && SHA256.HashData(data).AsSpan().SequenceEqual(NationalDayHash);
}
