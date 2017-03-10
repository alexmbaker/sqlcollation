using System.Windows.Forms;

namespace AlterCollation
{
    internal class Utils
    {
        private Utils()
        {
        }

        /// <summary>
        ///     build up a connection string for given some connection parameters
        /// </summary>
        /// <param name="server"></param>
        /// <param name="userId"></param>
        /// <param name="password"></param>
        /// <returns></returns>
        public static string ConnectionString(string server, string userId, string password)
        {
            if ((userId == null) || (userId.Length == 0))
                return
                    $"Data Source={server};Trusted_Connection=SSPI;Initial Catalog=master;Application Name=\"{Application.ProductName}\";Connect Timeout=5;Pooling=false;";
            return
                $"Application Name=\"{Application.ProductName}\";Connect Timeout=8;Persist Security Info=False;Database=master;User ID={userId};Password={password};Data Source={server};Connect Timeout=5;Pooling=false;";
        }
    }
}