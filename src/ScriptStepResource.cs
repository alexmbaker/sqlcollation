using System.Globalization;
using System.IO;
using System.Reflection;

namespace ChangeCollation
{
    public class ScriptStepResource : ScriptStep
    {
        public ScriptStepResource(string resourceIdentifier)
            : base(LoadResource(resourceIdentifier, null))
        {
        }

        public ScriptStepResource(string resourceIdentifier, object[] args)
            : base(LoadResource(resourceIdentifier, args))
        {
        }

        /// <summary>
        ///     load the sql from a SQL Resource file
        /// </summary>
        /// <param name="resourceIdentifier"></param>
        /// <param name="args"></param>
        /// <returns></returns>
        private static string LoadResource(string resourceIdentifier, object[] args)
        {
            var thisAssembly = Assembly.GetExecutingAssembly();
            var stream = thisAssembly.GetManifestResourceStream(resourceIdentifier);
            
            var reader = new StreamReader(stream);

            var retVal = reader.ReadToEnd();

            reader.Close();
            if (args != null)
                return string.Format(CultureInfo.InvariantCulture, retVal, args);
            return retVal;
        }
    }
}