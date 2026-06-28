using System;
using System.Web;
using System.Diagnostics;
using System.Threading.Tasks;

namespace AppDbSecrets
{
    public class Global : HttpApplication
    {
        protected void Application_Start(object sender, EventArgs e)
        {
            // O código de inicialização roda apenas uma vez quando a aplicação sobe (pool do IIS)
            Debug.WriteLine("=== INICIANDO A APLICAÇÃO ===");
            
            // É aqui que chamaremos nossa classe para ir até a AWS buscar o segredo.
            // (Implementaremos a lógica da AWS na próxima etapa)
            Task.Run(async () =>
            {
                try
                {
                    string secretValue = await SecretsService.GetSecretAsync();
                    
                    if (!string.IsNullOrEmpty(secretValue))
                    {
                        Debug.WriteLine("=== SEGREDO RECUPERADO COM SUCESSO ===");
                        Debug.WriteLine($"Conteúdo do Segredo: {secretValue}");
                        
                        // Em um cenário real, aqui você pegaria esse JSON/String,
                        // montaria sua SqlConnection string e passaria para o seu DbContext/Dapper.
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Falha crítica ao carregar configurações: {ex.Message}");
                }
            }).Wait(); // Bloqueia a inicialização até que o segredo seja resolvido
        }
    }
}