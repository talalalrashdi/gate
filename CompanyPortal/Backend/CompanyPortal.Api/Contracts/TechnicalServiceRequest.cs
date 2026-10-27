using System.ComponentModel.DataAnnotations;
namespace CompanyPortal.Api.Contracts;
public sealed class TechnicalServiceRequest
    {
        public Guid RequestKey {get;init;}
        public int? CategoryId {get;init;}
        public int? RecipientId {get;init;}
        public int? TypeId {get;init;}
        [StringLength(500)]public string? Title {get;init;}
        [Required,StringLength(4000)]public string Details {get;init;}="";
        [StringLength(100)]public string? OfficeNumber {get;init;}
        [StringLength(200)]public string? DocumentNumber {get;init;}
    }
