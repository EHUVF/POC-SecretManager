using System;
using System.Configuration;
using System.Diagnostics;
using System.Threading.Tasks;
using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;

namespace AppDbSecrets
{
    public static class SecretsService
    {
        public static async Task<string> GetSecretAsync()
        {
            try
            {
                Debug.WriteLine("Iniciando busca do segredo AWS...");

                string secretName = ConfigurationManager.AppSettings["AWSSecretName"];
                string region = ConfigurationManager.AppSettings["AWSRegion"];

                if (string.IsNullOrEmpty(secretName))
                {
                    Debug.WriteLine("Erro: AWSSecretName não configurado.");
                    throw new InvalidOperationException("AWSSecretName não configurado no AppSettings.");
                }

                if (string.IsNullOrEmpty(region))
                {
                    Debug.WriteLine("Erro: AWSRegion não configurado.");
                    throw new InvalidOperationException("AWSRegion não configurado no AppSettings.");
                }

                Debug.WriteLine($"Usando SecretName: {secretName}, Region: {region}");

                using (var client = new AmazonSecretsManagerClient(Amazon.RegionEndpoint.GetBySystemName(region)))
                {
                    var request = new GetSecretValueRequest
                    {
                        SecretId = secretName,
                        VersionStage = "AWSCURRENT" // Garante que pega a versão ativa do segredo
                    };

                    Debug.WriteLine($"Enviando requisição para buscar segredo: {secretName}");

                    var response = await client.GetSecretValueAsync(request);

                    if (response == null || string.IsNullOrEmpty(response.SecretString))
                    {
                        Debug.WriteLine("Erro: Resposta da AWS não contém segredo.");
                        throw new InvalidOperationException("Resposta da AWS não contém segredo.");
                    }

                    string secretValue = response.SecretString;

                    Debug.WriteLine("Segredo recuperado com sucesso.");

                    return secretValue;
                }
            }
            catch (ResourceNotFoundException ex)
            {
                Debug.WriteLine($"Erro: Segredo não encontrado. {ex.Message}");
                throw;
            }
            catch (InvalidRequestException ex)
            {
                Debug.WriteLine($"Erro: Requisição inválida para AWS Secrets Manager. {ex.Message}");
                throw;
            }
            catch (InvalidParameterException ex)
            {
                Debug.WriteLine($"Erro: Parâmetro inválido. {ex.Message}");
                throw;
            }
            catch (AmazonSecretsManagerException ex)
            {
                Debug.WriteLine($"Erro: Falha ao acessar AWS Secrets Manager. {ex.Message}");
                throw;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Erro inesperado ao buscar segredo: {ex.Message}");
                throw;
            }
        }
    }
}
