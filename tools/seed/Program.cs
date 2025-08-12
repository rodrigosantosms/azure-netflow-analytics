using Kusto.Ingest;
using Kusto.Data;
using Azure.Identity;
using System.Text.Json;

var uri = Environment.GetEnvironmentVariable("ADX_URI") ?? "";
var db  = Environment.GetEnvironmentVariable("ADX_DB") ?? "";
var ingest = KustoIngestFactory.CreateManagedStreamingIngestClient(new KustoConnectionStringBuilder(uri).WithAadAzureTokenCredentialsAuthentication(new DefaultAzureCredential()));

var rnd = new Random();
string[] vms = Enumerable.Range(1,30).Select(i => $"vm{i:00}").ToArray();
for (int i=0; i<2000; i++) {
    var src = vms[rnd.Next(vms.Length)];
    var dst = vms[rnd.Next(vms.Length)];
    var bytes = rnd.Next(10_000, 50_000_000);
    var doc = new {
        TimeGenerated = DateTime.UtcNow.AddMinutes(-rnd.Next(0,60)),
        SrcIp = $"10.0.{rnd.Next(0,20)}.{rnd.Next(4,250)}",
        DstIp = $"10.1.{rnd.Next(0,20)}.{rnd.Next(4,250)}",
        SrcPort = rnd.Next(1024, 65000),
        DstPort = new[]{80,443,1433,22,3389,53}[rnd.Next(6)],
        L4Protocol = rnd.Next(2)==0? "TCP":"UDP",
        Direction = rnd.Next(2)==0? "Inbound":"Outbound",
        Decision = "A",
        Bytes = bytes,
        Packets = bytes / 1400,
        StartTime = DateTime.UtcNow.AddMinutes(-rnd.Next(0,60)),
        EndTime = DateTime.UtcNow,
        TenantId = "demo",
        SubscriptionId = "demo",
        ResourceGroup = "demo",
        SrcVm = src, SrcVnet = "vnet-prod", SrcSubnet = "subnet-a",
        DstVm = dst, DstVnet = "vnet-prod", DstSubnet = "subnet-b",
        NsgRuleName = "Allow_HTTP",
        ServiceTag = "Internet",
        DstFqdn = "example.com",
        DstAsn = "AS15169",
        DstCountry = "US",
        ExpressRouteCircuit = "erc-01",
        ExpressRouteGateway = "ergw-01",
        PrivateEndpoint = "",
        PrivateLinkService = ""
    };
    var json = JsonSerializer.Serialize(doc);
    using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(json));
    await ingest.IngestFromStreamAsync(stream, new KustoIngestionProperties(db, "FlowLogsRaw"){ Format = DataSourceFormat.multijson });
}
Console.WriteLine("Seeded sample data.");
